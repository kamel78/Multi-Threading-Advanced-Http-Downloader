unit ThredingFileDownloader;

{********************************************************************************************
   Développer par Faraoun Kamel Mohamed
   Université Djilali Liabes -Sidi Bel Abbes - Algérie
   kamel_mh@yahoo.fr

   Multi-Thread Http Downloader component for FMX:Windows/Android/Mac...
   01 June 2022
********************************************************************************************}


interface

uses System.Net.HttpClient,System.Classes,System.SysUtils,FMX.Types,System.SyncObjs,FMX.Forms,System.NetEncoding,System.ioutils;

Type

  TSaveDownloadTrackState=Record
                          tStart,tEnd,
                          tProgress:Int64;
                          End;
  TSaveDownloadState=array of TSaveDownloadTrackState;
  TDownloadThreadDataEvent = procedure(const Sender: TObject; ThreadNo, ASpeed: Integer;AReadCount: Int64; APercentage:Double; var Abort: Boolean) of object;
  TDownloadInfoUpdateEvent=procedure(const Sender: TObject;AverageSpeed:Double;DownloadedAmount:Int64;DownloadedPercentage:Double;EstimatedReminingTime:Int64)of object;
  TFilenameChangedEvent=procedure(const Sender:TObject;Oldname:string;NewName:string)of object;
  TCannotResumeInfo=procedure(Const Sender: TObject;var cancel:boolean)of object;
  TTrackDownloader = class(TThread)
  private
    FOnThreadData: TDownloadThreadDataEvent;
  protected
    FURL, FFileName: string;
    FStartPoint, FEndPoint: Int64;
    FThreadNo: Integer;
    FTimeStart: Cardinal;
    FThSaveState:TSaveDownloadState;
    FFileSize:Int64;
    procedure ReceiveDataEvent(const Sender: TObject; AContentLength: Int64; AReadCount: Int64; var Abort: Boolean);
  public
    constructor Create(const URL, FileName: string; ThreadNo: Integer; StartPoint, EndPoint: Int64);
    destructor Destroy; override;
    procedure Execute; override;
    property OnThreadData: TDownloadThreadDataEvent write FOnThreadData;
  end;

  TThredingFileDownloader= class
        private
        FDownloadThreads: array of TTrackDownloader;
        FCriticalSection:TCriticalSection;
        FThreadsDownloadedAmout:array of Int64;
        FDownloadedAmount:Int64;
        [volatile]FIncrementTester:Int64;
        FDownloadedPerCentage:Double;
        [volatile]FDownloadSpeed:Double;
        FEstimatedRemainingTime:Int64;
        FNumOfThreads,FDefaultNumOfThreads:integer;
        [volatile]FFinished:boolean;
        [volatile]FStopDownload: Boolean;
        FIsDownloading:boolean;
        FFileSize:int64;
        FCanResume:boolean;
        FFilename,FUrl:String;
        FSaveStateStream:TFileStream;
        FOnDownloadThreadData:TDownloadThreadDataEvent;
        FONDownloadStarted,FOnDownloadTerminated,
        FOnDownloadPaused,FOnDownloadResumed,
        FOnDownloadError,FOnDownloadCanceled:TNotifyEvent;
        FOnDownloadInfoUpdate:TDownloadInfoUpdateEvent;
        FOnCannotResume:TCannotResumeInfo;
        FonFilenameChanged:TFilenameChangedEvent;
        FSpeedCalculator:TTimer;                   //        Used to compute
        FStartingDownload,FEndingDownload:Int64;   //        true instant download speed
        FStartingTime,FEndingTime:Cardinal;
        FSaveResumeProgress:TSaveDownloadState;
        FOutputPath:string;
        procedure ThreadReceiveDataHandler(const Sender: TObject; ThreadNo, ASpeed: Integer;AReadCount: Int64; APercentage:Double; var Abort: Boolean);
        procedure SpeedCalculatorEvent(Sender:Tobject);
        procedure _DoDownload(AskForResume:boolean=True);
        procedure _SaveDownloadState;
        procedure _SaveDownloadInfo;
        function _LoadDownloadState(wFilename:string):boolean;
        function _LoadDownloadInfo(wFilename: string):boolean;
        procedure _ResumeDownload;
        function _IndirectlyGetFileSize(wUrl:string):int64;
        procedure _IndirecrReceiveDataEvent(const Sender: TObject; AContentLength:Int64; AReadCount: Int64; var Abort: Boolean);
        function _CleanURL(wURL:string):string;
        public
        constructor Create;
        destructor destroy;override;
        procedure DoDownload;
        procedure PauseDownload;
        procedure ResumeDownload;
        procedure CancelDownload;
        function StandarizedSize(value:Int64):string;
        function ResumeFromTempFile(wFilename:String):integer;
        property NumOfThreads:integer read FNumOfThreads write FDefaultNumOfThreads default 4;
        property Filename:string read FFilename;
        property URL:string read FUrl write FUrl;
        property OnThredDownloadingData:TDownloadThreadDataEvent read FOnDownloadThreadData write FOnDownloadThreadData;
        property OnDownloadTerminated:TNotifyEvent read FOnDownloadTerminated write FOnDownloadTerminated;
        property OnDownloadError:TNotifyEvent read FOnDownloadError write FOnDownloadError;
        property OnDownloadInfoUpdate:TDownloadInfoUpdateEvent read FOnDownloadInfoUpdate write FOnDownloadInfoUpdate;
        property OnDownloadStarted :TNotifyEvent read FONDownloadStarted write FONDownloadStarted;
        property OnDownloadPaused:TNotifyEvent read FOnDownloadPaused write FOnDownloadPaused;
        property OnDownloadResumed:TNotifyEvent read FOnDownloadResumed write FOnDownloadResumed;
        property OnCannotResume:TCannotResumeInfo read FOnCannotResume write FOnCannotResume;
        property OnDownloadCanceled:TNotifyEvent read FOnDownloadCanceled write FOnDownloadCanceled;
        property ActiveFileSize:int64 read FFileSize;
        property OutputPath:string read FOutputPath write FOutputPath;
        property IsDownloading:boolean read FIsDownloading;
        property IsResumeSupported:boolean read FCanResume;
        end;


implementation
       uses MainForm;
    { TThredingFileDownloader }

///*******************************************************************************************************************************************************//
constructor TThredingFileDownloader.Create;
begin
FDefaultNumOfThreads:=4;
FFinished:=False;
FStopDownload:=False;
FDownloadedAmount:=0;
FDownloadedPerCentage:=0;
FDownloadSpeed:=0;
FSpeedCalculator:=TTimer.Create(nil);
FSpeedCalculator.Parent:=nil;
FSpeedCalculator.Interval:=2000;
FSpeedCalculator.OnTimer:=SpeedCalculatorEvent;
Setlength(FSaveResumeProgress,0);
FOutputPath:=ExtractFilePath(ParamStr(0));
end;

///*******************************************************************************************************************************************************//
function TThredingFileDownloader._CleanURL(wURL: string): string;
var tmp:string;
begin
tmp:=wURL;
if not UpperCase(tmp).StartsWith('HTTP') then begin
                                              Result:='';
                                              exit;
                                              end;
if pos('?',tmp)>0 then tmp:=Copy(tmp,1,Pos('?',tmp)-1);
Result:=Tmp;
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader._DoDownload;
var wClient: THTTPClient;
    wResponse: IHTTPResponse;
    wStrmFile: TFileStream;
    wStart, wEnd, wSize, wFragSize: Int64;
    i: Integer;
    wFilename,zFilename:String;
    CancelDownload:boolean;
begin
wClient := THTTPClient.Create;
wResponse := wClient.Head(FURL);
if wResponse.StatusCode<>200 then begin
                                  if Assigned(FOnDownloadError) then TThread.Synchronize(nil,procedure
                                                                                       begin
                                                                                       FOnDownloadError(Self);
                                                                                       end);
                                  exit;
                                  end;
FStartingTime:=TThread.GetTickCount;
FStartingDownload:=0;
FCriticalSection:=TCriticalSection.Create;
try
try
  FURL:=_CleanURL(FURL);
  if FURL='' then begin
                  raise Exception.Create('Invalid Url for download, only http/https protocols are supported .....');
                  exit;
                  end;
  FCanResume:=wClient.CheckDownloadResume(FURL);
  if FCanResume then FNumOfThreads:=FDefaultNumOfThreads
  else begin
       FNumOfThreads:=1;
       CancelDownload:=False;
       if Assigned(FOnCannotResume)and AskForResume then TThread.Synchronize(nil,procedure begin FOnCannotResume(Self,CancelDownload);end);
       if CancelDownload then exit;
       end;
  wSize := wResponse.ContentLength;
  if wSize=-1 then wSize:=_IndirectlyGetFileSize(Furl);
  FFilename:=ExtractFileName(URL.Replace('/','\'));
  if wResponse.ContainsHeader('Content-Disposition')
  then wFilename:=wResponse.GetHeaderValue('Content-Disposition')
  else if wResponse.ContainsHeader('content-disposition')
  then wFilename:=wResponse.GetHeaderValue('content-disposition')
  else wFilename:='';
  if wFilename<>'' then begin
                        if pos('"',wFilename)>0 then wFilename:=wFilename.Split(['"'])[1]
                        else wFilename:=wFilename.Split(['='])[1];
                        end;
  if wFilename<>'' then FFilename:=wFilename
  else if FFilename='' then raise Exception.Create('Unknown file name, download cannot be performed ...');
  FFileSize:=wSize;
  SetLength(FDownloadThreads, FNumOfThreads);
  SetLength(FThreadsDownloadedAmout, FNumOfThreads);
  SetLength(FSaveResumeProgress, FNumOfThreads);
  wStrmFile := TFileStream.Create(FOutputPath+'_'+FFileName+'.temporary', fmCreate);
  try
    wStrmFile.Size := wSize+(FNumOfThreads*24+1)+(Length(TEncoding.UTF8.GetBytes(FURL))+2);
    finally
      wStrmFile.Free;
  end;
  FSaveStateStream:= TFileStream.Create(FOutputPath+'_'+FFileName+'.temporary', fmOpenWrite or fmShareDenyNone);
  _SaveDownloadInfo;
  wFragSize := wSize div FNumOfThreads;
  wStart := 0;
  wEnd := wStart + wFragSize;
  for i := 0 to FNumOfThreads-1 do begin
                                   if FFinished then Break;
                                   FThreadsDownloadedAmout[i]:=0;
                                   FDownloadThreads[I] := TTrackDownloader.Create(URL, FOutputPath+'_'+FFileName+'.temporary', i, wStart, wEnd);
                                   FDownloadThreads[I].OnThreadData := ThreadReceiveDataHandler;
                                   FDownloadThreads[I].FThSaveState:=FSaveResumeProgress;
                                   FDownloadThreads[I].FFileSize:=FFileSize;
                                   FSaveResumeProgress[I].tStart:=wStart;
                                   FSaveResumeProgress[I].tEnd:=wEnd;
                                   FSaveResumeProgress[i].tProgress:=0;
                                   wStart := wStart + wFragSize;
                                   wEnd := wStart + wFragSize;
                                   end;
  for i := 0 to FNumOfThreads-1 do FDownloadThreads[I].Start;
  FIsDownloading:=True;
  if Assigned(FONDownloadStarted) then TThread.Synchronize(nil,procedure begin FONDownloadStarted(Self);end);
  FSpeedCalculator.Enabled:=True;
  FFinished := False;
  while not FFinished do begin
                         FFinished := True;
                         for i := 0 to FNumOfThreads-1 do FFinished := FFinished and FDownloadThreads[I].Finished;
                         end;
  FSpeedCalculator.Enabled:=False;
  FIsDownloading:=False;
  FFinished:=False;
  for i := 0 to FNumOfThreads-1 do FDownloadThreads[I].Free;
  SetLength(FDownloadThreads,0);
  SetLength(FThreadsDownloadedAmout,0);
  if not FStopDownload then begin
                            SetLength(FSaveResumeProgress,0);
                            if Assigned(FOnDownloadTerminated) then TThread.Synchronize(nil,procedure begin FOnDownloadTerminated(Self);end);
                            end;
  Except
    if Assigned(FOnDownloadError) then TThread.Synchronize(nil,procedure begin FOnDownloadError(Self);end);
    end;
    finally
      wClient.Free;
      FCriticalSection.Free;
      if not CancelDownload then begin
      if not FStopDownload then FSaveStateStream.Size:=FSaveStateStream.Size-FNumOfThreads*24-1-Length(TEncoding.UTF8.GetBytes(FURL))-2;
      FSaveStateStream.Free;
      if not FStopDownload then begin
                                i:=0;
                                wFilename:=FFilename;
                                zFilename:=FFilename;
                                if FileExists(wFilename) then begin
                                    repeat
                                    i:=i+1;
                                    wFilename:=Tpath.GetFileNameWithoutExtension(FFilename)+i.ToString+ExtractFileExt(FFilename);
                                    until (not FileExists(wFilename));
                                    RenameFile(FOutputPath+'_'+FFileName+'.temporary',FOutputPath+wFilename);
                                    FFilename:=wFilename;
                                    if Assigned(FonFilenameChanged) then TThread.Synchronize(nil,procedure
                                                                                               begin
                                                                                               FonFilenameChanged(Self,zFilename,FFilename);
                                                                                               end);
                                    end
                                else RenameFile(FOutputPath+'_'+FFileName+'.temporary',FOutputPath+FFilename);
                                end;
                                end;
      FStopDownload:=False;
end;
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader.CancelDownload;
begin
if not FIsDownloading then exit;
FStopDownload:=True;
Sleep(50);
Repeat
Application.ProcessMessages;
until not FStopDownload;
if Assigned(FOnDownloadCanceled) then FOnDownloadCanceled(Self);
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader._ResumeDownload;
var wClient: THTTPClient;
    wResponse: IHTTPResponse;
    wStrmFile: TFileStream;
    wStart, wEnd, wSize, wFragSize: Int64;
    i: Integer;
    wFilename,zFilename:String;
    cancel:boolean;
begin
wClient := THTTPClient.Create;
FStartingTime:=TThread.GetTickCount;
FStartingDownload:=0;
FCriticalSection:=TCriticalSection.Create;
try
try
 if FCanResume then begin
                    FNumOfThreads:=length(FSaveResumeProgress);
                    wFragSize := wSize div FNumOfThreads;
                    SetLength(FDownloadThreads, FNumOfThreads);
                    SetLength(FThreadsDownloadedAmout, FNumOfThreads);
                    for i := 0 to FNumOfThreads-1 do
                                      begin
                                      if FFinished then Break;
                                      FDownloadThreads[I] := TTrackDownloader.Create(URL, FOutputPath+'_'+FFileName+'.temporary', i, FSaveResumeProgress[i].tStart+FSaveResumeProgress[i].tProgress, FSaveResumeProgress[i].tEnd);
                                      FDownloadThreads[I].OnThreadData := ThreadReceiveDataHandler;
                                      FDownloadThreads[I].FThSaveState:=FSaveResumeProgress;
                                      FDownloadThreads[I].FFileSize:=FFileSize;
                                      end;
                    FSaveStateStream:= TFileStream.Create(FOutputPath+'_'+FFileName+'.temporary', fmOpenWrite or fmShareDenyNone);
                    for i := 0 to FNumOfThreads-1 do FDownloadThreads[I].Start;
                    if Assigned(FOnDownloadResumed) then TThread.Synchronize(nil,procedure begin FOnDownloadResumed(Self);end);
                    FSpeedCalculator.Enabled:=True;
                    FFinished := False;
                    while not FFinished do
                      begin
                      FFinished := True;
                      for i := 0 to FNumOfThreads-1 do FFinished := FFinished and FDownloadThreads[I].Finished;
                      end;
                    FSpeedCalculator.Enabled:=False;
                    for i := 0 to FNumOfThreads-1 do FDownloadThreads[I].Free;
                    FIsDownloading:=False;
                    FFinished:=False;
                    if not FStopDownload then
                    if Assigned(FOnDownloadTerminated) then TThread.Synchronize(nil,procedure begin FOnDownloadTerminated(Self);end);
                    end
    else begin
         Cancel:=true;
         if Assigned(FOnCannotResume) then TThread.Synchronize(nil,procedure begin FOnCannotResume(Self,Cancel);end);
         if not cancel then _DoDownload(False);
         end;
    Except
    if Assigned(FOnDownloadError) then FOnDownloadError(Self);
    end;
    finally
      wClient.Free;
      FCriticalSection.Free;
      if not FStopDownload then FSaveStateStream.Size:=FSaveStateStream.Size-FNumOfThreads*24-1-Length(TEncoding.UTF8.GetBytes(FURL))-2;
      FSaveStateStream.Free;
      if not FStopDownload then begin
                                i:=0;
                                wFilename:=FFilename;
                                zFilename:=FFilename;
                                if FileExists(wFilename) then begin
                                    repeat
                                    i:=i+1;
                                    wFilename:=Tpath.GetFileNameWithoutExtension(FFilename)+i.ToString+ExtractFileExt(FFilename);
                                    until (not FileExists(wFilename));
                                    RenameFile('_'+FFileName+'.temporary',wFilename);
                                    FFilename:=wFilename;
                                    if Assigned(FonFilenameChanged) then TThread.Synchronize(nil,procedure
                                                                                               begin
                                                                                               FonFilenameChanged(Self,zFilename,FFilename);
                                                                                               end);
                                    end
                                else RenameFile('_'+FFileName+'.temporary',FFilename);

                                end;
      FStopDownload:=False;
end;
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader._SaveDownloadInfo;
var Tmp:TBytes;
    wSaveResumeInfo:TSaveDownloadState;
    i:integer;
    wLength:Word;
begin
Tmp:=TEncoding.UTF8.GetBytes(FURL);
wLength:=Length(Tmp);
Setlength(Tmp,Length(Tmp)+2);
Tmp[Length(Tmp)-2]:=Hi(wLength);
Tmp[Length(Tmp)-1]:=Lo(wLength);
  try
    FSaveStateStream.Seek(FFileSize, TSeekOrigin.soBeginning);
    FSaveStateStream.Write(Tmp,length(Tmp));
  finally
  end;
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader._SaveDownloadState;
var Tmp:TBytes;
    wSaveResumeProgress:TSaveDownloadState;
    i:integer;
begin
Setlength(wSaveResumeProgress,length(FSaveResumeProgress));
for i:=0 to Length(FSaveResumeProgress)-1 do begin
                                             wSaveResumeProgress[i].tStart:=FSaveResumeProgress[i].tStart;
                                             wSaveResumeProgress[i].tEnd:=FSaveResumeProgress[i].tEnd;
                                             wSaveResumeProgress[i].tProgress:=FThreadsDownloadedAmout[i];
                                             end;

SetLength(Tmp,length(wSaveResumeProgress)*24+1);
Tmp[length(Tmp)-1]:=length(FSaveResumeProgress);
Move(wSaveResumeProgress[0],Tmp[0],Length(Tmp)-1);
  try
    FSaveStateStream.Seek(FFileSize+Length(TEncoding.UTF8.GetBytes(FURL))+2, TSeekOrigin.soBeginning);
    FSaveStateStream.Write(Tmp,length(Tmp));
  finally
  end;
end;

///*******************************************************************************************************************************************************//
function TThredingFileDownloader._LoadDownloadState(wFilename: string):boolean;
var LStream: TFileStream;
    Tmp:TBytes;
begin
SetLength(Tmp,1);
Result:=True;
Setlength(FSaveResumeProgress,0);
LStream := TFileStream.Create(FOutputPath+wFileName, fmOpenRead);
Try
  try
    LStream.Seek(LStream.Size-1, TSeekOrigin.soBeginning);
    LStream.Read(Tmp[0],1);
    setlength(FSaveResumeProgress,Tmp[0]);
    SetLength(Tmp,Tmp[0]*24);
    LStream.Seek(LStream.Size-1-Length(Tmp), TSeekOrigin.soBeginning);
    LStream.Read(Tmp[0],Length(Tmp));
    Move(Tmp[0],FSaveResumeProgress[0],Length(Tmp));
    except
    Result:=False;
    end;
  finally
      LStream.Free;
  end;
end;

///*******************************************************************************************************************************************************//
function TThredingFileDownloader._LoadDownloadInfo(wFilename: string):boolean;
var LStream: TFileStream;
    Tmp:TBytes;
    wLength:Word;
begin
Result:=true;
SetLength(Tmp,2);
LStream := TFileStream.Create(FOutputPath+wFileName, fmOpenRead);
try
  try
    LStream.Seek(LStream.Size-(Length(FSaveResumeProgress)*24+1)-2, TSeekOrigin.soBeginning);
    LStream.Read(Tmp[0],2);
    wLength:=Tmp[0]*256+Tmp[1];
    SetLength(Tmp,wLength);
    FFileSize:=LStream.Size-(Length(FSaveResumeProgress)*24+1)-(Length(Tmp)+2);
    LStream.Seek(FFileSize , TSeekOrigin.soBeginning);
    LStream.Read(Tmp,Length(Tmp));
    FUrl:=TEncoding.UTF8.GetString(Tmp);
    except
    Result:=false;
    end;
  finally
      LStream.Free;
  end;
end;

///*******************************************************************************************************************************************************//
destructor TThredingFileDownloader.destroy;
begin
inherited;
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader.DoDownload;
begin
TThread.CreateAnonymousThread(procedure begin
                                        _DoDownload;
                                        end).Start;
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader.PauseDownload;
begin
FStopDownload:=True;
if Assigned(FOnDownloadPaused) then TThread.Synchronize(nil,procedure begin FOnDownloadPaused(Self);end);
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader.ResumeDownload;
begin
_LoadDownloadState('_'+FFileName+'.temporary');
_LoadDownloadInfo('_'+FFileName+'.temporary');
if Length(FSaveResumeProgress)>0 then TThread.CreateAnonymousThread(procedure begin
                                                                     _ResumeDownload;
                                                                     end).Start
else raise Exception.Create('No saved state exist to resume download ');
end;

///*******************************************************************************************************************************************************//
function TThredingFileDownloader.ResumeFromTempFile(wFilename: String):integer;
var LStream:TFileStream;
begin
Result:=0;
if not _LoadDownloadState(wFilename) or(wFilename[1]<>'_')or(ExtractFileExt(wFilename)<>'.temporary') then raise Exception.Create('Invalid temporary file for download resume...')
else begin
     FFilename:=wFilename.Replace('_','').Replace('.temporary','');
     Result:=Length(FSaveResumeProgress);
     FCanResume:=True;
     ResumeDownload;
     end;
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader.SpeedCalculatorEvent(Sender: Tobject);
var wTime:Cardinal;
    wSpeed:Double;
    wDownloaded:Int64;
begin
FEndingTime:=TThread.GetTickCount;
FEndingDownload:=FDownloadedAmount;
wTime:=FEndingTime-FStartingTime;
wDownloaded:=FEndingDownload-FStartingDownload;
FStartingTime:=FEndingTime;
FStartingDownload:=FEndingDownload;
wSpeed:=Round(((wDownloaded*1000)/wTime)*100)/100;
FDownloadSpeed:=wSpeed;
end;

///*******************************************************************************************************************************************************//
function TThredingFileDownloader.StandarizedSize(value: Int64): string;
begin
if Value<1024 then Result:=value.ToString+' Byte'
else if value<1024*1024 then Result:=(Round((Value/1024)*100)/100).ToString+' KB'
else if value<1024*1024*1024 then  Result:=(Round((Value/(1024*1024))*100)/100).ToString+' MB'
else Result:=(Round((Value/(1024*1024*1024))*100)/100).ToString+' GB';
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader.ThreadReceiveDataHandler(const Sender: TObject; ThreadNo, ASpeed: Integer;AReadCount: Int64;APercentage:Double; var Abort: Boolean);
var i:integer;
    wAverageDownloaded:Double;
    wRemainingTime:Int64;
    wAbort:boolean;
begin
if not FStopDownload then begin
                          FCriticalSection.Enter;
                          FThreadsDownloadedAmout[ThreadNo]:=AReadCount+FSaveResumeProgress[ThreadNo].tProgress;
                          _SaveDownloadState;
                          FDownloadedAmount :=0;
                          for i:=0 to FNumOfThreads-1 do FDownloadedAmount:=FDownloadedAmount+FThreadsDownloadedAmout[i];
                          if FDownloadedAmount>FFileSize then
                          i:=1;

                          if FFileSize>-1 then begin
                                               FDownloadedPerCentage:=(FDownloadedAmount/FFileSize)*100;
                                               FDownloadedPerCentage:=Round(FDownloadedPerCentage*100)/100;
                                               end
                          else FDownloadedPerCentage:=-1;
                          if FFileSize>-1 then wRemainingTime:=Round((FFileSize-FDownloadedAmount)/FdownloadSpeed) // Estimated Remaining time in second
                          else wRemainingTime:=-1;
                          FEstimatedRemainingTime:=wRemainingTime;
                          FCriticalSection.Release;
                          if Assigned(FOnDownloadThreadData) then begin
                                                                  wAbort:=Abort;
                                                                  TThread.Synchronize(nil,procedure begin
                                                                  FOnDownloadThreadData(Sender,ThreadNo,ASpeed,AReadCount+FSaveResumeProgress[ThreadNo].tProgress, APercentage,wAbort);
                                                                  end);
                                                                  Abort:=wAbort;
                                                                  end;
                          if Assigned(FOnDownloadInfoUpdate) then
                                  TThread.Synchronize(nil, procedure begin
                                  FOnDownloadInfoUpdate(Self,FDownloadSpeed,FDownloadedAmount,FDownloadedPerCentage,FEstimatedRemainingTime);
                                  end);
                          end;
Abort:=FStopDownload;
end;

{ TDownloadThread }

///*******************************************************************************************************************************************************//
constructor TTrackDownloader.Create(const URL, FileName: string; ThreadNo: Integer; StartPoint, EndPoint: Int64);
begin
  inherited Create(True);
  FURL := URL;
  FFileName := FileName;
  FThreadNo := ThreadNo;
  FStartPoint := StartPoint;
  FEndPoint := EndPoint;
end;

///*******************************************************************************************************************************************************//
destructor TTrackDownloader.Destroy;
begin
  inherited;
end;

///*******************************************************************************************************************************************************//
procedure TTrackDownloader.Execute;
var LResponse: IHTTPResponse;
    LStream: TFileStream;
    LHttpClient: THTTPClient;
begin
inherited;
LHttpClient := THTTPClient.Create;
try
  LHttpClient.OnReceiveData := ReceiveDataEvent;
  LStream := TFileStream.Create(FFileName, fmOpenWrite or fmShareDenyNone);
  try
    FTimeStart := GetTickCount;
    LStream.Seek(FStartPoint, TSeekOrigin.soBeginning);
    LResponse := LHttpClient.GetRange(FURL, FStartPoint, FEndPoint, LStream);
  finally
      LStream.Free;
  end;
  finally
    LHttpClient.Free;
end;
end;

///*******************************************************************************************************************************************************//
procedure TTrackDownloader.ReceiveDataEvent(const Sender: TObject; AContentLength:Int64; AReadCount: Int64; var Abort: Boolean);
var LTime: Cardinal;
    LSpeed: Integer;
    LPrecentage:Double;
begin
if Assigned(FOnThreadData) then begin
                                LTime := GetTickCount - FTimeStart;
                                if AReadCount = 0 then LSpeed := 0
                                else LSpeed := (AReadCount * 1000) div LTime;   // Byte per Second
                                if FFileSize>-1 then
                                LPrecentage:=Round(((AReadCount+FThSaveState[FThreadNo].tProgress)/(AContentLength+FThSaveState[FThreadNo].tProgress))*10000)/100
                                else LPrecentage:=-1;
                                FOnThreadData(Sender, FThreadNo, LSpeed,AReadCount, LPrecentage, Abort);
                                end;
end;

///*******************************************************************************************************************************************************//
procedure TThredingFileDownloader._IndirecrReceiveDataEvent(const Sender: TObject; AContentLength:Int64; AReadCount: Int64; var Abort: Boolean);
begin
FIncrementTester:=AContentLength;
Abort:=True
end;

function TThredingFileDownloader._IndirectlyGetFileSize(wUrl: string): int64;
var wClient:THTTPClient;
    wResponce:IHTTPResponse;
begin
wClient:=THTTPClient.Create;
wClient.OnReceiveData:=_IndirecrReceiveDataEvent;
FIncrementTester:=0;
try
wResponce:=wClient.Get(wUrl);
Sleep(100);
Result:=FIncrementTester;
finally
wClient.Free;
end;
end;



end.
