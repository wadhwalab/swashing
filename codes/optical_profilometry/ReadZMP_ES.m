% ReadZMP.m
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% provides file transfer functions for Matlab to read Zemetrics .zmp-files
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 2012/04/02 Wolfgang Kaehler
% (c) 2012 by Zygo/Zemetrics
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all;            % make workspace empty
clc;                  % make screen empty
close all;            % close all windows with figures  
%warning off MATLAB:divideByZero
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%declaration/defines
verbosity = false;

if strfind(computer('arch'),'win')>0
    filepath= '.\';
else
    filepath= './';
end
% show file open dialog

[filename,filepath] = uigetfile('*.zmp','Please select ZMP file',filepath);
if ~isequal(filename, 0)
    filename=strcat(filepath,filename);
    disp(filename);
else
    return;
end

%disable the previous lines with the file dialog and enable the following
%to load the test map file in the same directory as this source file

%filename = 'test.zmp';

MLVer=ver('Matlab');
[mainver,remain]=strtok(MLVer.Version,'.');
subver=strtok(remain,'.');
if (str2double(mainver) >= 7) && (str2double(subver) > 5)
    [lError, InfoHeader, Map]=ReadZMPFileME(filename, verbosity);
else
    [lError, InfoHeader, Map]=ReadZMPFile(filename, verbosity);
end

if lError==0
    disp('file read successfully.');
    %file successfully loaded, display information
    %from this point on you can write your own code to get information
    %from the map, display it or parts of it
    disp('InfoHeader =');
    disp(InfoHeader);
    disp (['Spatial resolution in X = ' num2str(InfoHeader.XScale) ' mm/pix']);
    disp (['Spatial resolution in Y = ' num2str(InfoHeader.YScale) ' mm/pix']);
    disp (['Spatial resolution in Z = ' num2str(InfoHeader.ZScale) ' \mu m/pix']);

    %calculate map size x,y in mm
    mapSizeX = double(InfoHeader.Cols) * InfoHeader.XScale;
    mapSizeY = double(InfoHeader.Rows) * InfoHeader.YScale;
    disp (['Field size in X = ' num2str(mapSizeX) ' mm']);
    disp (['Field size in Y = ' num2str(mapSizeY) ' mm']);
    
    %calculate RMS from valid pixels, void pixels are NaN
    RMS=std(Map(~isnan(Map(:))));
    %calculate minimum
    minMap = min(Map(~isnan(Map(:))));
    %calculate maximum
    maxMap = max(Map(~isnan(Map(:))));
    %calculate peak-to-valley
    PV=maxMap-minMap;

    disp(['Min map = ' num2str(minMap)])
    disp(['Max map = ' num2str(maxMap)])
    disp(['Peak-to-valley = ' num2str(PV)])

    %count void pixels
    voidPixels = sum(isnan(Map(:)));
    %count valid pixels
    validPixels = sum(~isnan(Map(:)));
    disp(['Number of void pixels: ' num2str(voidPixels) ' , number of valid Pixels: ' num2str(validPixels)]);

    %zeros the map
    zeroedMap= Map - (minMap * ones(size(Map,1), size(Map,2)));

    %get rid of Nans, also removes some of the boundaries for smoothing
    filledMissingMap = fillmissing(zeroedMap,'knn', 10);

    filledzeroedMap = filledMissingMap(80:size(zeroedMap,1)-80,80:size(zeroedMap,2)-80);
    filledZeroedAdjustedMap = filledzeroedMap/1000;

    % Define x and y coordinates
    [x, y] = meshgrid(1:size(filledZeroedAdjustedMap, 2), 1:size(filledZeroedAdjustedMap, 1));
    
    %calculate minimum
    minMap = min(filledZeroedAdjustedMap(~isnan(filledZeroedAdjustedMap(:))));
    maxMap = max(filledZeroedAdjustedMap(~isnan(filledZeroedAdjustedMap(:))));

    colorlimiter = [minMap maxMap];

    %prepare map display in figure window
    %therefore set units to pixels
    set(0,'Units','pixels');
    scrsz = get(0,'ScreenSize');

    %generate a figure window in the middle of the screen of half size
    %of the screen
    figure('Position',[scrsz(3)/4 scrsz(4)/4 scrsz(3)/2 scrsz(4)/2]);

    %display map
    imagesc(filledZeroedAdjustedMap,colorlimiter);
    
    % Allow the user to select two points
    disp('Select two points on the plot');
    [x_selected, y_selected] = ginput(2);
    
    % Find the zeroedMap values at the selected points
    z1x = interp2(x, y, filledZeroedAdjustedMap, x_selected(1), y_selected(1));
    z2x = interp2(x, y, filledZeroedAdjustedMap, x_selected(2), y_selected(1));

    z1y = interp2(x, y, filledZeroedAdjustedMap, x_selected(1), y_selected(1));
    z2y = interp2(x, y, filledZeroedAdjustedMap, x_selected(1), y_selected(2));
    
    % Calculate the slope
    delta_x = x_selected(2) - x_selected(1);
    delta_y = y_selected(2) - y_selected(1);

    delta_zx = z2x - z1x;
    delta_zy = z2y - z1y;

    dzdx=delta_zx/delta_x;
    dzdy=delta_zy/delta_y;
    
    % Fit a plane to the two points to detrend the plot
    zeroedMap_detrended = filledZeroedAdjustedMap - (dzdx*x + dzdy*y);
    
    %rezeroes the map
    zeroedMap_detrended=zeroedMap_detrended - abs(min(zeroedMap_detrended(~isnan(zeroedMap_detrended(:)))));

    %update color scheme
    minMap = min(zeroedMap_detrended(~isnan(zeroedMap_detrended(:))));
    maxMap = max(zeroedMap_detrended(~isnan(zeroedMap_detrended(:))));

    colorlimiter = [minMap maxMap];

    %save('Filtered_Colony_Profile.mat',  'zeroedMap_detrended');

    % Plot the detrended surface with enhanced appearance for publication
    figure('Name', 'Final Profilometry', 'Position', [scrsz(3)/4 scrsz(4)/4 scrsz(3)/2 scrsz(4)/2]);
    
    % Main 3D surface plot
    surf(x * InfoHeader.XScale, y * InfoHeader.YScale, zeroedMap_detrended);
    colormap(hot);
    
    % Axis labels with larger font size and bold text
    xlabel('mm', 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('mm', 'FontSize', 20, 'FontWeight', 'bold');
    zlabel('Height (\mum)', 'FontSize', 20, 'FontWeight', 'bold');
    
    % Improve shading and colormap for better detail
    shading interp;
    axis tight;
    camlight;
    lighting phong;
    
    % Add a semi-translucent gray plane at y = 3 mm
    hold on;
    [xPlane, zPlane] = meshgrid(linspace(min(x(1,:)) * InfoHeader.XScale, max(x(1,:)) * InfoHeader.XScale, 100), ...
                                linspace(min(zeroedMap_detrended(:)), max(zeroedMap_detrended(:)), 100));
    yPlane = 3 * ones(size(xPlane)); % y = 3 mm
    surf(xPlane, yPlane, zPlane, 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'FaceColor', [0.5, 0.5, 0.5]);
    
    % Set the view angle
    view(220, 25);
    
    % Add color bar with label
    %c = colorbar;
    %c.Label.String = 'Height (\mum)';
    
    % Set the ratio of axes
    pbaspect([5 5 2]);
    
    % Set font and line properties for publication quality
    set(gca, 'FontSize', 20, 'FontName', 'Arial', 'LineWidth', 1.5, 'FontWeight', 'bold');
    %print('-dpng', '-r350', 'surf-plot-1-17.png');
    hold off;
    
    % Create a top-down 2D plot with color bar
    figure('Name', 'Top-Down View', 'Position', [scrsz(3)/4 scrsz(4)/4 scrsz(3)/2 scrsz(4)/2]);
    minMap = min(zeroedMap_detrended(~isnan(zeroedMap_detrended(:))));
    maxMap = max(zeroedMap_detrended(~isnan(zeroedMap_detrended(:))));

    colorlimiter = [minMap maxMap];

    %imagesc(zeroedMap_detrended,colorlimiter);
    imagesc(x(1,:) * InfoHeader.XScale, y(:,1) * InfoHeader.YScale, zeroedMap_detrended, colorlimiter);
    colormap(hot);
    
    % Axis labels
    xlabel('mm', 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('mm', 'FontSize', 20, 'FontWeight', 'bold');
    
    % Add color bar with label
    %c = colorbar;
    %c.Label.String = 'Height (\mum)';
    
    % Adjust axes and appearance
    axis tight;
    axis equal;
    set(gca, 'FontSize', 20, 'FontName', 'Arial', 'LineWidth', 1.5, 'FontWeight', 'bold');
    %print('-dsvg', '-r350', 'top-down-plot-1-17.svg');

    % 2D Line Plot: Height vs. X-Axis at y = 3 mm
    figure('Name', 'Height vs X-Axis at y = 3 mm', 'Position', [scrsz(3)/4 scrsz(4)/4 scrsz(3)/2 scrsz(4)/2]);
    
    % Find the index corresponding to y = 3 mm
    [~, yIndex] = min(abs(y * InfoHeader.YScale - 3));
    
    % Extract data at y = 3 mm
    zData = zeroedMap_detrended(yIndex, :); % Height values
    
    % Plot the line
    plot(x(1,:)*InfoHeader.XScale, zData(1,:), 'LineWidth', 2);
    grid on;
    
    % Axis labels
    xlabel('mm', 'FontSize', 20, 'FontWeight', 'bold');
    ylabel('Height (\mum)', 'FontSize', 20, 'FontWeight', 'bold');
    
    % Set font and line properties for publication quality
    set(gca, 'FontSize', 20, 'FontName', 'Arial', 'LineWidth', 1.5, 'FontWeight', 'bold');
    %title('Height Profile at y = 3 mm', 'FontSize', 22, 'FontWeight', 'bold');
    %print('-dsvg', '-r350', 'height-profile-plot-1-17.svg');

    % Plot the detrended surface with enhanced appearance for publication
    %figure('Name', 'Final Profilometry', 'Position',[scrsz(3)/4 scrsz(4)/4 scrsz(3)/2 scrsz(4)/2]);
    
    %surf(x * InfoHeader.XScale, y * InfoHeader.YScale, zeroedMap_detrended);
    %colormap(hot);
    
    % Axis labels with larger font size and bold text
    %xlabel('X-axis (mm)', 'FontSize', 20, 'FontWeight', 'bold');
    %ylabel('Y-axis (mm)', 'FontSize', 20, 'FontWeight', 'bold');
    %zlabel('Height (\mum)', 'FontSize', 20, 'FontWeight', 'bold');
    
    % Improve shading and colormap for better detail
    %shading interp;
    %axis tight
    %camlight
    %lighting phong
    %shading interp
   
    %view(70,40);  %set the view 

    %c = colorbar;
    %c.Label.String = 'Height (\mum)';
    
    %ratio of axes
    %pbaspect([5 5 2])

    % Set font and line properties for publication quality
    %set(gca, 'FontSize', 20, 'FontName', 'Arial', 'LineWidth', 1.5, 'FontWeight', 'bold');

    
%     **** get the average thickness
%     % create a box
%     [X Y] = ginput(2)       % make you select X number of points defining the background
%     X = int16(X);
%     Y = int16(Y);
%     k = 0; % (counts the empty points)
%     for i = Y(1):Y(2)
%         for j = X(1):X(2)
%             if isnan(Map(i,j))
%                 k = k +1;
%                 Map2(i-Y(1)+1,j-X(1)+1) = 0;
%             else
%                 Map2(i-Y(1)+1,j-X(1)+1) = Map(i,j);
%             end
%         end
%     end
%     
%     subplot(2,1,1)
%        imagesc(Map2,colorlimiter);
%  
%        for i = 1:length(Map2)
%            t(i) = mean(Map2(:,i));
%        end
%        
%     subplot(2,1,2)
%        plot(t)
%        axis tight
           
             
% mapSize = size(Map);
% MapX = uint16(Map.*0);
% MapY = uint16(Map.*0);
% X = 1:mapSize(1);
% Y = 1:mapSize(2);
% for i = 1:mapSize(2);
%     MapX(:,i) = X;
% end
% for i = 1:mapSize(1);
%     MapY(i,:) = Y;
% end
% 
%     
%     
% surf(MapX,MapY,Map,'EdgeColor','none')
% grid off

% title({['Map file: ' filename], ...
%         ['Min: ' num2str(minMap,'%7.3f') ' nm, Max: ' num2str(maxMap,'%7.3f') ' nm, PV: ' num2str(PV,'%7.3f') ' nm, RMS: ' num2str(RMS,'%7.3f') ' nm'], ...
%         ['Number of void pixels: ' num2str(voidPixels) ' , number of valid Pixels: ' num2str(validPixels)]});
%     colormap(hot);
% %     colormap(hsv);
%     colorbar;
else
    disp(['error reading file : ' filename]);
end




