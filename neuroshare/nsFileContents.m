function nsFileContents()

[fileName,pathName] = uigetfile('*.*', 'Select the NSX File to View.');
fullFilePath = [pathName, fileName];

[nsresult, hfile] = ns_OpenFile(fullFilePath);
 
% Get file information
[nsresult, FileInfo] = ns_GetFileInfo(hfile);
% Gives you EntityCount, TimeStampResolution and TimeSpan
 
FileInfo

% Build catalogue of entities
for k = 1:1:FileInfo.EntityCount
    [nsresult, EntityInfo(k)] = ns_GetEntityInfo(hfile, k);
end

NeuralList = find([EntityInfo.EntityType] == 4);    % List of EntityIDs needed to retrieve the information and data
SegmentList = find([EntityInfo.EntityType] == 3);
AnalogList = find([EntityInfo.EntityType] == 2);
EventList = find([EntityInfo.EntityType] == 1);
 
% How many of a particular entity do we have
cNeural = length(NeuralList)      
cSegment = length(SegmentList)
cAnalog = length(AnalogList)
cEvent = length(EventList)

entityItemCounts = [EntityInfo.ItemCount];

