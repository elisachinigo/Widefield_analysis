function [data,dffdata] = reconstructData(U,V);

data = (V*U')'; %raw vid corrected for hemo signal
dffdata = (data-median(data,2))./(median(data,2)); 

end 