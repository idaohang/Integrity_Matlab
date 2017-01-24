
% This script runs a localization simulator with DA and P(IA)



clear; close all;
dbstop if error
configfile; % ** USE THIS FILE TO CONFIGURE THE EKF-SLAM **


% Setup plots
fig=figure;
plot(lm(1,:),lm(2,:),'b*')
hold on, axis equal
plot(wp(1,:),wp(2,:), 'g', wp(1,:),wp(2,:),'g.')
xlabel('metres'), ylabel('metres')
set(fig, 'name', 'EKF-SLAM Simulator')
h= setup_animations;
veh= [0 -WHEELBASE -WHEELBASE; 0 -2 2]; % vehicle animation
plines=[]; % for laser line animation
pcount=0;


% *****************    MAIN LOOP    *****************
while iwp ~= 0
    if step > NUMBER_STEPS, break, end
    step= step + 1;
        
    % Compute true data
    [G,iwp]= compute_steering(xtrue, wp, iwp, AT_WAYPOINT, G, RATEG, MAXG, dt);
    if iwp==0 && NUMBER_LOOPS > 1, pack; iwp=1; NUMBER_LOOPS= NUMBER_LOOPS-1; end % perform loops: if final waypoint reached, go back to first
    xtrue= vehicle_model(xtrue, V,G, WHEELBASE,dt);
    [Vn,Gn]= add_control_noise(V,G,Q, SWITCH_CONTROL_NOISE);
    
    % EKF predict step
    predict (Vn,Gn,QE, WHEELBASE,dt);
        
    % Incorporate observation, (available every DT_OBSERVE seconds)
    dtsum= dtsum + dt;
    if dtsum >= DT_OBSERVE
        dtsum= 0;
        
        % get measurements
        [z,idft]= get_observations(xtrue, lm, ftag, MAX_RANGE); 
        z= add_observation_noise(z,R, SWITCH_SENSOR_NOISE);
        
        % DA
        if ~isempty(z)
            if SWITCH_ASSOCIATION == 0
                [zf,idf,zn, da_table]= data_associate_known(XX,z,idft, da_table);
            elseif SWITCH_ASSOCIATION == 1
                [zf,idf, zn]= data_associate_localNN(XX,PX,z,RE, GATE_REJECT, GATE_AUGMENT);
            elseif SWITCH_ASSOCIATION == 2
                [gamma,H,Y,idf,PCA(step),PCAt(step),allOutliers]= ...
                    DA(XX,PX,z,idft,RE,GATE,V_FOV,LAMBDA,P_D,'outliers');
            end
            
            if ~allOutliers
                % update the state
                K= PX*H'/Y;
                XX= XX + K*gamma;
                PX= (eye(3) - K*H)*PX;
%                 PX= PX - K*H*PX*H'*K';
            end
        else
            PCA(step)= 1;
        end
    end
    errorXX(step,:)= abs(xtrue - XX)';
    stdXX(step,:)= 3*sqrt(diag(PX))';
    realPCA(step)= 1 - IA/step;
    calcPCA(step)= sum(PCA)/step;

    % Plots
    if SWITCH_GRAPHICS
        
        xt= transformtoglobal(veh, xtrue);
        set(h.xt, 'xdata', xt(1,:), 'ydata', xt(2,:))
        
        xv= transformtoglobal(veh, XX(1:3));
        pvcov= make_vehicle_covariance_ellipse(XX,PX);
        set(h.xv, 'xdata', xv(1,:), 'ydata', xv(2,:))
        set(h.vcov, 'xdata', pvcov(1,:), 'ydata', pvcov(2,:))
        
%         pcount= pcount+1;
%         if pcount == 120 % plot path infrequently
%             pcount=0;
%             set(h.pth, 'xdata', DATA.path(1,1:DATA.i), 'ydata', DATA.path(2,1:DATA.i))
%         end
        
        if dtsum==0 && ~isempty(z) % plots related to observations
            set(h.xf, 'xdata', XX(4:2:end), 'ydata', XX(5:2:end))
            plines= make_laser_lines (z,XX(1:3));
            set(h.obs, 'xdata', plines(1,:), 'ydata', plines(2,:))
        end
        drawnow
    end
    
    
end 
% *****************  END OF MAIN LOOP    *****************

%% Post-processing
if SWITCH_PROFILE, profile report, end

% clean extra allocated memory
PCA(step+1:end)= [];
PCAt(step+1:end)= [];
realPCA(step+1:end)= [];
calcPCA(step+1:end)= [];
errorXX(step+1:end,:)= [];
stdXX(step+1:end,:)= [];

% plots - P(CA) VS time
figure; hold on; grid on;
plot(PCA,'-b');
plot(PCAt,'or');
idx= find(PCAt == 0);
for i= 1:length(idx)
    line([idx(i),idx(i)],[0,1],'color','red');
end
axis([0,step,0,1]);

% % plots - Error Vs Covariance - X & Y
% figure; hold on; grid on
% plot(errorXX(:,1),'b-');
% plot(errorXX(:,2),'r-');
% plot(stdXX(:,1),'b--','linewidth',5);
% plot(stdXX(:,2),'r--','linewidth',5);
% for i= 1:length(idx)
%     line([idx(i),idx(i)],[0,max(stdXX(:))],'color','black');
% end
% xlabel('time')
% ylabel('m')
% legend('error X','error Y','covariance X','covariance Y','location','southeast');

% % plots - Error Vs Covariance - phi
% figure; hold on; grid on
% plot(errorXX(:,3),'g-');
% plot(stdXX(:,3),'g--','linewidth',5);
% for i= 1:length(idx)
%     line([idx(i),idx(i)],[0,max(stdXX(:,3))],'color','black');
% end
% xlabel('time')
% ylabel('rad')
% legend('error phi','covariance phi','location','southeast');

% plots - realPCA Vs calcPCA
figure; hold on; grid on
plot(realPCA,'-b','linewidth',2);
plot(calcPCA,'r-','linewidth',2);
legend('Real P(CA)','Average calculated P(CA)','location','southeast');
axis([0,step,0,1]);



% find(errorXX(:,1) > stdXX(:,1))
% find(errorXX(:,2) > stdXX(:,2))
% find(errorXX(:,3) > stdXX(:,3))




