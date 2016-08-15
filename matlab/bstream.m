% BSTREAM - Calculates the barotropic streamfunction%%  M. den Toom%% SYNTAX%%  PSIM = bstream(u,varz,vary)%% DESCRIPTION%%  Calculates the barotropic streamfunction from u, by integrating over%  depth, using the bounding coordinates in varz, and subsequently%  integrating over latitude, using the bounding coordinates in vary.%function [PSIM,UINTZ,UINTY] = bstream(u,varz,vary)%fprintf(1,'Barotropic streamfunction...\n')%% - ERROR CHECK -if (ndims(u)~=3)    error('The u field must be three dimensional')elseif (size(u,2)~=length(vary)-1)    error('The latitudinal coordinate does not match the u field')elseif (size(u,3)~=length(varz)-1)    error('The depth coordinate does not match the u field')end%% - INTEGRATION -for k = 1:length(varz)-1    u(:,:,k)  = u(:,:,k)*(varz(k+1)-varz(k));endUINTZ  = sum(u,3);UINTY  = UINTZ;for j = 1:length(vary)-1    UINTY(:,j) = UINTY(:,j)*(vary(j+1)-vary(j));endPSIMm  = -fliplr(cumsum(fliplr(UINTY),2))/1.e6;UINTY  = UINTZ;for j = 1:length(vary)-1    UINTY(:,j) = UINTY(:,j)*(vary(j+1)-vary(j));endPSIMp  = (cumsum((UINTY),2))/1.e6;PSIdiff1 = ((PSIMm(:,2:end) - PSIMp(:,1:end-1)));PSIdiff2 = ((PSIMp(:,1:end-1) - PSIMm(:,2:end)));idx = logical(PSIdiff1(:) < -3) & logical(PSIdiff1(:) > -4);PSIdiff1(idx) = 0;figure(1);imagesc(abs(PSIdiff1)');colorbarcaxis([-50,50])set(gca,'ydir','normal');figure(2);imagesc(abs(PSIdiff2)');colorbarcaxis([-50,50])set(gca,'ydir','normal');PSIM = PSIMm;input('')PSIM  = [zeros(1,size(PSIM,2));PSIM];