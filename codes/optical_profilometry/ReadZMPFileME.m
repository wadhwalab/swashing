%+FUH----------------------------------------------------------------------
% ReadZMPFile(filename);
% content: Read Zemetrics .zmp file in Matrix for further operation
% parameters: filename
% returns: Error, InfoHeader of ZMP data,
%          Map as Matrix [unit, Nanometer]
%-FUH----------------------------------------------------------------------
% 2012/04/02 Wolfgang Kaehler
% (c) 2012 by Zygo/Zemetrics
function [lError, InfoHeader, Map]=ReadZMPFileME(filename, varargin)
% declarations/defines
    optInputArgSize = size(varargin,2);
    if optInputArgSize>0        
        verbosity = varargin{1};
        if verbosity
            disp(['number of optional inputs: ' num2str(optInputArgSize)]);
            disp('verbosity is : true');
        end
    else
        verbosity = false;
    end
    bbreak = false;
    lError=-1;
    InfoHeader=struct;
    Map=0;
%implementation
    warning off all
    fid = fopen(filename,'r');
    try
        message = ferror(fid);
        disp(message);        
    catch me
        emessage=strcat('File doesn''''t exist or there is an access violation to file : ',filename, ' . ', me.message);
        errordlg(emessage,'File Type Error','modal');
%        message = ferror(fid,'clear');
        return;
    end
    
    try
        eof = false;
        while ~eof
            tag = ReadAnsiString(fid);
            
            if isempty(tag)
                if verbosity
                    disp('Break due to empty tag, before EOF.');
                end
                break;
            end
            
            switch tag
                case 'EOF'
                    if verbosity
                        disp('Reached EOF tag.');
                    end
                    bbreak = true;
                case 'Zemetrics.Map.v1'
                    InfoHeader.FileId = tag;
                case 'DxDy'
                    i1=fread(fid,1,'*uint32'); % 2 x 4 byte
                    if verbosity
                        disp(['read DxDy :' num2str(i1)]);
                    end
                    InfoHeader.Rows=fread(fid,1,'*int32');
                    InfoHeader.Cols=fread(fid,1,'*int32');
                case 'XYZScale'
                    i2=fread(fid,1,'*uint32'); % 3 x 8 byte
                    if verbosity
                        disp(['read XYZScale :' num2str(i2)]);
                    end
                    InfoHeader.XScale=fread(fid,1,'*double');
                    InfoHeader.YScale=fread(fid,1,'*double');
                    InfoHeader.ZScale=fread(fid,1,'*double');                    
                case 'XYOrigin'
                    i3=fread(fid,1,'*uint32'); % 2 x 8 byte
                    if verbosity
                        disp(['read XYOrigin :' num2str(i3)]);
                    end
                    InfoHeader.XOrigin=fread(fid,1,'*double');
                    InfoHeader.YOrigin=fread(fid,1,'*double');                    
                case 'Data'
                    i7=fread(fid,1,'*uint32');
                    if verbosity
                        disp(['read Data : ' num2str(i7) ' Bytes.']);
                    end
                    
                    Map=zeros(double(InfoHeader.Rows),double(InfoHeader.Cols));
                    if verbosity
                        disp(['allocated Map memory : ' num2str(i7) ' Bytes.']);
                    end
                    Map(:)=NaN;
                    MapTemp=double(fread(fid,[double(InfoHeader.Cols) double(InfoHeader.Rows)],'*int32'))';
                    if verbosity
                        disp('Map read successfully.');
                    end
                    MapTemp(MapTemp == 2147483647)=NaN;
                    if verbosity
                        disp('Map bad data points set to NaN successfully.');
                    end
                    Map=MapTemp.*InfoHeader.ZScale;
                    if verbosity
                        disp('Map scaled successfully.');
                    end
                    
                    if isempty(Map)
                        Map=0;
                        if verbosity
                            disp('Map empty, something went wrong.');
                        end
                    end
                otherwise
                    length=ReadBlock(fid);
                    if isfield(InfoHeader,tag)
                       if verbosity
                           disp(['Already existing tag ' tag ' read and applied successfully.']);
                       end
                        tag = strcat(tag,'1');
                    end
                    eval(['InfoHeader.' tag '=''' num2str(length) ' Bytes'';']);                    
                    if verbosity
                        disp(['InfoHeader.' tag ' read successfully.']);
                    end                    
            end
            
            if bbreak
                break;
            end
                                    
            eof=feof(fid);
        end
        lError = fclose(fid);
        if verbosity
            disp('File closed successfully.');
        end
    catch me
        errordlg(getReport(me,'extended','hyperlinks','off'),'Error in ReadZMPFile','modal');
        lError=-1;
    end
    return;
end
        
function [aString] = ReadAnsiString(fid)
    rlen = double(fread(fid,1,'*uint8'));
    aString=fread(fid,rlen,'*char')';
    return;
end

function [length] = ReadBlock(fid)
    length = double(fread(fid,1,'*uint32'));
    fread(fid,length,'*uint8');
    return;
end