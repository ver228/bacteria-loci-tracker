function [bgMean,bgStd] = spatialMovAveBG(imageLast5,imageSizeX,imageSizeY)

%the function in its current form assigns blocks of 11x11 pixels the
%same background values, for the sake of speed

%define pixel limits where moving average can be calculated
startPixelX = 16;
endPixelX = imageSizeX - 15;
startPixelY = 16;
endPixelY = imageSizeY - 15;

%allocate memory for output
bgMean = NaN(imageSizeX,imageSizeY);
bgStd = bgMean;

%go over all pixels within limits
for iPixelX = startPixelX : 11 : endPixelX
    for iPixelY = startPixelY : 11 : endPixelY
        
        %get local image
        imageLocal = imageLast5(iPixelX-15:iPixelX+15,iPixelY-15:iPixelY+15,:);
        
        %estimate robust mean and std
        %first remove NaNs representing cropped regions
        in = ~isnan(imageLocal);
        imageLocal = imageLocal(in);
        if ~isempty(imageLocal)
            [bgMean1,bgStd1] = robustMean2(imageLocal(:));
        else
            bgMean1 = NaN;
            bgStd1 = NaN;
        end
        
        %put values in matrix representing image
        bgMean(iPixelX-5:iPixelX+5,iPixelY-5:iPixelY+5) = bgMean1;
        bgStd(iPixelX-5:iPixelX+5,iPixelY-5:iPixelY+5) = bgStd1;
        
    end
end
%{
%find limits of actual pixels filled up above
firstFullX = find(~isnan(bgMean(:,startPixelY)),1,'first');
lastFullX = find(~isnan(bgMean(:,startPixelY)),1,'last');
firstFullY = find(~isnan(bgMean(startPixelX,:)),1,'first');
lastFullY = find(~isnan(bgMean(startPixelX,:)),1,'last');

%patch the rest
for iPixelY = firstFullY : lastFullY
    bgMean(1:firstFullX-1,iPixelY) = bgMean(firstFullX,iPixelY);
    bgMean(lastFullX+1:end,iPixelY) = bgMean(lastFullX,iPixelY);
    bgStd(1:firstFullX-1,iPixelY) = bgStd(firstFullX,iPixelY);
    bgStd(lastFullX+1:end,iPixelY) = bgStd(lastFullX,iPixelY);
end
for iPixelX = 1 : imageSizeX
    bgMean(iPixelX,1:firstFullY-1) = bgMean(iPixelX,firstFullY);
    bgMean(iPixelX,lastFullY+1:end) = bgMean(iPixelX,lastFullY);
    bgStd(iPixelX,1:firstFullY-1) = bgStd(iPixelX,firstFullY);
    bgStd(iPixelX,lastFullY+1:end) = bgStd(iPixelX,lastFullY);
end
%}