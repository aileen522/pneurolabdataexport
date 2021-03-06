function [ns_RESULT, Data] = ...
    ns_GetAnalogDataBlock(hFile, EntityIDs, StartIndex, IndexCount, scaleFlag)
% Usage:
% [ns_RESULT, ns_RESULT] = NS_GETANALOGDATABLOCK(hFile, EntityIDs,
%    StartIndex, IndexCount, scaleFlag)
%
% Description:
% Returns the data values associated with the Analog (continuious) data
% for multiple electrodes in a single file read.  If data for multiple
% electrodes is desired this will result in much faster reading than the
% corresponding function NS_GETANALOGDATA.  If extracting data from only
% one electrode NS_GETANALOGDATABLOCK is comparable with NS_GETANALOGBLOCK.
%
% Parameters:
% hFile                            A handle that contains information for 
%                                  one or more files. hFile is obtained by
%                                  a call to ns_OpenFile.  The result of 
%                                  ns_OpenFile, hFile, can be given as an 
%                                  argument in its entirety, or a subset of
%                                  the hFile array can be given.
%
% EntityIDs                        List of EntityIDs for desired data.
%                                  Entity IDs must correspond to data from
%                                  a single NSx file (generally data with
%                                  a single sampling rate).
%
% StartIndex                       The index (sample number) to start 
%                                  analog data extraction. This field is 
%                                  ignored if the pointer is set to NULL.
%
% IndexCount                       Number of analog values to retrieve.
%
% scaleFlag                        Optional.  Default: 'scale'.  If 'scale'
%                                  return data as double with scaling applied.  
%                                  Else, return ADC values as int16.
%                                  
% Return Values:
% Data                             A cell array with data corresponding to
%                                  and in the same order as the electrodes 
%                                  found in EntityIDs.
%
% ns_RESULT          This function returns one of the following status 
%                    codes:
%
%   ns_OK              The file was successfully opened. 
%   ns_BADFILE         Invalid file handle passed to function. 
%   ns_BADENTITY       Invalid or inappropriate entity identifier specified
%   ns_FILEERROR       File access or read error
%
% See also NS_OPENFILE, NS_GETENTITYINFO, NS_GETANALOGINFO
% NS_GETANALOGDATA, NS_CLOSEFILE

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%     The Wisteria Neuroshare Importer is free software: you can 
%     redistribute it and/or modify
%     it under the terms of the GNU General Public License as published by
%     the Free Software Foundation, either version 3 of the License, or
%     (at your option) any later version.
% 
%     The Wisteria Neuroshare Importer is distributed in the hope that it 
%     will be useful, but WITHOUT ANY WARRANTY; without even the implied 
%     warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
%     See the GNU General Public License for more details.
% 
%     You should have received a copy of the GNU General Public License
%     along with the Wisteria Neuroshare Importer.  If not, see 
%     <http://www.gnu.org/licenses/>.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ContCount = [];
Data = [];

% check input arguments
if ~isstruct(hFile)
    ns_RESULT = 'ns_BADFILE';
    return
end

% check EntityIDs
if ~isnumeric(EntityIDs) || ...
    any(strcmp({hFile.Entity(EntityIDs).EntityType}, 'Analog')==0)
        % any(uint16(EntityIDs)~=EntityIDs)||...
    ns_RESULT = 'ns_BADENTITY';
    return
end

% Check IndexCount
% if ~isnumeric([StartIndex,IndexCount])||IndexCount<1||StartIndex<1
%    ns_RESULT = 'ns_BADINDEX';
%     return
% end

ns_RESULT = 'ns_OK';

fileType = unique([hFile.Entity(EntityIDs).FileType]);
% Require only entities from only a single NSX file at a time
if length(fileType) > 1
  ns_RESULT = 'ns_BADENTITY';
  return;
end
% create a space to place retrieved data
fileData = [];

useScale = 1;
if nargin == 5
  if strcmp(scaleFlag, 'unscale')
    useScale = 0;
  end
end
% The largest amount of data that we could read.  After the data is read,
% the extra NaN's will be cut out.
% This may break with a large number of pausing...
Data = [];
fileInfo = hFile.FileInfo(fileType);
% Get an entity that corresponds to this entity so that we may make use
% of Neuroshare functions such as ns_GetIndexByTime below.
firstEntity = find([hFile.Entity(:).FileType] == fileType, 1);
% If this is first run through pre-allocate Data with NaN, we should do
% highest sampled data first so that we should only need to do this once.
% if isempty(Data)
%   Data = NaN(length(EntityIDs), readCount);
% end
% sampleRate = 30000 / fileInfo.Period;
% calculate packet information
indexTotal = min(StartIndex + IndexCount - 1, hFile.Entity(firstEntity).Count);
IndexCount = indexTotal - StartIndex + 1;
% Get the number of points for each "pause" or data packet 
nPointAll = cumsum(fileInfo.TimeStamps(2,:));
startPacket = find(StartIndex <= nPointAll, 1, 'first');
endPacket = find(indexTotal <= nPointAll, 1, 'first');
nPacket = length(startPacket:endPacket);
nChannel = length(fileInfo.ElectrodeList);
bytesSkip = 2 * nChannel;
if useScale
  Data = zeros(length(EntityIDs), IndexCount);
else
  Data = zeros(length(EntityIDs), IndexCount, 'int16');
end
% More or less randomly put read only 10e8 points at once (each point is
% two bytes).  If this number gets bigger, we have less reads, but risk
% running out of memory.  Should we actually check memory size before this
% step?
maxRead = floor(10e8 / nChannel);
% calculate olffset to skip to the start of the first packets.
offset = double(fileInfo.BytesHeaders) + ...
  startPacket * 9 * strcmp(fileInfo.FileTypeID, 'NEURALCD') + ...
  bytesSkip * (StartIndex - 1);
entityList = find([hFile.Entity(:).FileType] == fileType);
wantedChannels = zeros(size(EntityIDs));
for i=1:length(wantedChannels)
  wantedChannels(i) = ismembc2(EntityIDs(i), entityList);
end
wantedChannels = wantedChannels(wantedChannels ~= 0);
fseek(fileInfo.FileID, offset, -1);
% create read size for each data Packet
readCount = min(IndexCount, maxRead);
if nPacket == 1
  packetSize = IndexCount;
else
  % NOTE: Why not use "nPacket"
  packetSize = fileInfo.TimeStamps(2, startPacket:endPacket);
  packetSize(1) = packetSize(1) - StartIndex + 1;
  packetSize(end) = packetSize(end) - (sum(packetSize) - IndexCount);
end
% calculate the number of bytes needed to skip for a single sample.  This
% is the number of entities in the file times 2 for int16.
% calculate offset
CountList = [0, cumsum(packetSize)];
% seek to start position of wanted file from beginning of file
% 
% Read through data taking care with pauses.
for k = 1:nPacket
  currentPoint = CountList(k);
  packetRead = 0;
  % 
  while packetRead < packetSize(k)
    % we either read the max number of points or to the end of this set of
    % data packets.
    currentRead = min(packetSize(k) - packetRead, maxRead);
    % read block of data
    readData = ...
      fread(fileInfo.FileID, [nChannel, currentRead], '*int16');
    % Copy wanted data return value.  If scaling will be used, convert to
    % double.
    if useScale
      Data(:, currentPoint + 1:currentPoint + currentRead) = ...
        double(readData(wantedChannels, :));
    else
      Data(:,currentPoint + 1:currentPoint + currentRead) = ...
        readData(wantedChannels, :);
    end
    % advance the read marker for overall file
    currentPoint = currentPoint + currentRead;
    % advance the read marker at the packet level
    packetRead = packetRead + currentRead;
  end
  fseek(fileInfo.FileID, 9, 0);
end
% rescale data if desired.
if useScale
  Data = Data*hFile.Entity(end).Scale;
end
