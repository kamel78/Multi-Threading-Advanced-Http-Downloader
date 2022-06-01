unit MainForm;

{********************************************************************************************
   Développer par Faraoun Kamel Mohamed
   Université Djilali Liabes -Sidi Bel Abbes - Algérie
   kamel_mh@yahoo.fr

   Multi-Thread Http Downloader component for FMX:Windows/Android/Mac...
   01 June 2022
********************************************************************************************}


interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.StdCtrls,
  FMX.Controls.Presentation, FMX.Edit, System.Rtti,FMX.Grid.Style, FMX.ScrollBox,
  FMX.Grid, FMX.Memo, System.Net.URLClient,System.Net.HttpClient, System.Net.HttpClientComponent,
  MultiCircularProgress,ThredingFileDownloader, FMX.Objects, FMX.Layouts,
  Data.Cloud.CloudAPI, Data.Cloud.AzureAPI, FMX.ListBox, IdBaseComponent,
  IdComponent, IdTCPConnection, IdTCPClient, IdHTTP, IdIOHandler,
  IdIOHandlerSocket, IdIOHandlerStack, IdSSL, IdSSLOpenSSL;

type
  TForm1 = class(TForm)
    Rectangle1: TRectangle;
    Layout1: TLayout;
    Layout2: TLayout;
    Layout3: TLayout;
    Layout4: TLayout;
    Layout5: TLayout;
    Layout6: TLayout;
    Label14: TLabel;
    Label15: TLabel;
    Label16: TLabel;
    Label17: TLabel;
    Label18: TLabel;
    Label19: TLabel;
    Label20: TLabel;
    Label21: TLabel;
    Layout7: TLayout;
    Label22: TLabel;
    Label23: TLabel;
    Layout8: TLayout;
    Label24: TLabel;
    Label25: TLabel;
    Layout9: TLayout;
    Label3: TLabel;
    Label4: TLabel;
    Layout10: TLayout;
    Image1: TImage;
    OpenDialog1: TOpenDialog;
    Layout11: TLayout;
    Label5: TLabel;
    Panel1: TPanel;
    Label9: TLabel;
    Label1: TLabel;
    ComboBox1: TComboBox;
    Button1: TButton;
    Button2: TButton;
    Label2: TLabel;
    Edit2: TEdit;
    Button3: TButton;
    Label6: TLabel;
    ComboBox2: TComboBox;
    Button4: TButton;
    Layout12: TLayout;
    StringGrid1: TStringGrid;
    StringColumn1: TStringColumn;
    StringColumn2: TStringColumn;
    StringColumn3: TStringColumn;
    StringColumn4: TStringColumn;
    ComboBox3: TComboBox;
    Label7: TLabel;
    Edit1: TEdit;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure ComboBox2Change(Sender: TObject);
    procedure Button4Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure Button5Click(Sender: TObject);
    procedure ComboBox3Change(Sender: TObject);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
    Downloader:TThredingFileDownloader;
    ProgresShow:TMultiCircularProgress;
    DetailsHeight:Integer;
    procedure ResetDisplay;
    procedure onDownloadUpdateInfo(const Sender: TObject;AverageSpeed:Double;DownloadedAmount:Int64;DownloadedPercentage:Double;EstimatedReminingTime:Int64);
    procedure OnDownloadStart(Sender :TObject);
    procedure OnDownloadError(Sender:TObject);
    procedure OnDownloadPaused(Sender:TObject);
    procedure OnDownloadResumed(Sender:TObject);
    procedure OnThreadDownload(const Sender: TObject; ThreadNo, ASpeed: Integer;AReadCount: Int64; APercentage:Double; var Abort: Boolean);
    procedure OnCannotResume(const Sender:TObject;var cancel:boolean);
    procedure OnDownloadTerminated(Sender:TObject);
    procedure OnDownloadCanceled(Sender:TObject);
  end;

var
  Form1: TForm1;

implementation

{$R *.fmx}

procedure TForm1.Button1Click(Sender: TObject);
begin
if (Sender as TButton).tag=0 then begin
                                  (Sender as TButton).Text:='Cancel';
                                  Downloader.URL:=Edit1.Text;
                                  Downloader.OutputPath:=Edit2.Text;
                                  Downloader.NumOfThreads:=ComboBox1.Items[ComboBox1.ItemIndex].ToInteger;
                                  (Sender as TButton).Tag:=1;
                                  Downloader.DoDownload;
                                  ComboBox1.Enabled:=False;
                                  end
else begin
     (Sender as TButton).Text:='Start';
     if MessageDlg('Do you want to cancel the active download ?',TMsgDlgType.mtConfirmation,[TMsgDlgBtn.mbyes,TMsgDlgBtn.mbno],0)=mryes
     then begin
          Downloader.CancelDownload;
          (Sender as TButton).Tag:=0;
          end;
     end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
if (Sender as TButton).Tag=0 then begin
                                  (Sender as TButton).Tag:=1;
                                  (Sender as TButton).Text:='Resume';
                                  Downloader.PauseDownload;
                                  end
else begin
     (Sender as TButton).Tag:=0;
     (Sender as TButton).Text:='Pause';
     Downloader.ResumeDownload;
     end;
end;

procedure TForm1.Button3Click(Sender: TObject);
var wDirectory:string;
begin
wDirectory:=Edit2.Text;
if SelectDirectory('Select Directory', ExtractFileDrive(wDirectory), wDirectory) then Edit2.Text:=wDirectory;
end;

procedure TForm1.Button4Click(Sender: TObject);
begin
if (Sender as TButton).Tag=0 then begin
                                  (Sender as TButton).Tag:=1;
                                  (Sender as TButton).Text:='Show Details >>';
                                  DetailsHeight:=Round(Layout12.Height);
                                  Height:=Height-DetailsHeight;
                                  end
else begin
     (Sender as TButton).Tag:=0;
     (Sender as TButton).Text:='Mask Details <<';
     Height:=Height+DetailsHeight;
     end;
end;

procedure TForm1.Button5Click(Sender: TObject);
begin
//ProgresShow.NumberOfTracks:=Downloader.ResumeFromTempFile('_reaConverterStandard-Setup.exe.temporary');
end;

procedure TForm1.ComboBox1Change(Sender: TObject);
begin
ResetDisplay;
end;

procedure TForm1.ComboBox2Change(Sender: TObject);
begin
ProgresShow.ShowPies:=True;
ProgresShow.ShowArcs:=True;
case ComboBox2.ItemIndex of
1:ProgresShow.ShowPies:=False;
2:ProgresShow.ShowArcs:=False;
end;
Application.ProcessMessages;
end;

procedure TForm1.ComboBox3Change(Sender: TObject);
begin
Edit1.Text:=ComboBox3.Selected.Text;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
Downloader:=TThredingFileDownloader.Create;
Downloader.OnDownloadInfoUpdate:=onDownloadUpdateInfo;
Downloader.OnDownloadStarted:=OnDownloadStart;
Downloader.OnDownloadError:=OnDownloadError;
Downloader.OnThredDownloadingData:=OnThreadDownload;
Downloader.OnDownloadPaused:=OnDownloadPaused;
Downloader.OnCannotResume:=OnCannotResume;
Downloader.OnDownloadResumed:=OnDownloadResumed;
Downloader.OnDownloadTerminated:=OnDownloadTerminated;
Downloader.OnDownloadCanceled:=OnDownloadCanceled;
ProgresShow:=TMultiCircularProgress.Create(Layout1);
ProgresShow.ProgressBackColor:=$FFE0E0E0;
ProgresShow.Align:=TAlignLayout.Client;
ProgresShow.Width:=ProgresShow.Height;
ProgresShow.Margins.Left:=5;
ProgresShow.Margins.Top:=5;
ProgresShow.Margins.Bottom:=5;
ProgresShow.Margins.Right:=5;
ProgresShow.NumberOfTracks:=Downloader.NumOfThreads;
Edit2.Text:=Downloader.OutputPath;
StringGrid1.RowCount:=Downloader.NumOfThreads;
StringGrid1.Columns[0].Header:='N°';
StringGrid1.Columns[1].Header:='Speed';
StringGrid1.Columns[2].Header:='Downloaded';
StringGrid1.Columns[3].Header:='Progress';
ResetDisplay;
ComboBox3.ItemIndex:=0;
end;

procedure TForm1.OnCannotResume(const Sender: TObject; var cancel: boolean);
begin
Cancel:=MessageDlg('Resume is not Support !, do you wan to continue download anyway ?.',TMsgDlgType.mtwarning,[TMsgDlgBtn.mbyes,TMsgDlgBtn.mbno],0)<>mryes;
if cancel then ResetDisplay;
end;

procedure TForm1.OnDownloadCanceled(Sender: TObject);
begin
ResetDisplay;
end;

procedure TForm1.OnDownloadError(Sender: TObject);
begin
MessageDlg('Unexpected error has occured while downloading the current file, download will be aborted..',TMsgDlgType.mtError,[TMsgDlgBtn.mbOK],0);
end;

procedure TForm1.OnDownloadResumed(Sender: TObject);
begin
// Any code you want to run when download is canceled
end;

procedure TForm1.OnDownloadStart(Sender: TObject);
begin
Label15.Text:=Downloader.Filename;
ProgresShow.ResetProgress;
ProgresShow.NumberOfTracks:=Downloader.NumOfThreads;
if Downloader.ActiveFileSize>-1 then Label16.Text:=Downloader.StandarizedSize(Downloader.ActiveFileSize)
else begin
     Label16.Text:='Unknown';
     ProgresShow.ForceProgressTextValue('Unknown');
     end;
if Downloader.IsResumeSupported then begin
                                     Label3.Text:='Supported';
                                     Label3.TextSettings.FontColor:=TAlphaColorRec.Green;
                                     end
else begin
     Label3.Text:='Not supported';
     Label3.TextSettings.FontColor:=TAlphaColorRec.Red;
     end;
Button2.Enabled:=Downloader.IsResumeSupported;
end;

procedure TForm1.OnDownloadPaused(Sender: TObject);
begin
//  Any code you want to run when download is Paused
end;

procedure TForm1.OnDownloadTerminated(Sender: TObject);
begin
MessageDlg('Download of the file "'+Downloader.Filename+'" is completed.',TMsgDlgType.mtInformation,[TMsgDlgBtn.mbOK],0);
ResetDisplay;
end;

procedure TForm1.onDownloadUpdateInfo(const Sender: TObject;AverageSpeed: Double; DownloadedAmount: Int64; DownloadedPercentage: Double;EstimatedReminingTime: Int64);
begin
Label18.Text:=Downloader.StandarizedSize(Round(AverageSpeed))+'/s';
Label24.Text:=Downloader.StandarizedSize(DownloadedAmount);
if DownloadedPercentage>-1 then Label20.text:=DownloadedPercentage.ToString+'%' else Label20.Text:='Unknown';
if EstimatedReminingTime>-1 then Label22.Text:=FormatDateTime('hh:nn:ss', EstimatedReminingTime / SecsPerDay)
else Label22.Text:='Unknown';
end;

procedure TForm1.OnThreadDownload(const Sender: TObject; ThreadNo,ASpeed: Integer; AReadCount: Int64; APercentage: Double; var Abort: Boolean);
begin
StringGrid1.Cells[1,ThreadNo]:=Downloader.StandarizedSize(Round(ASpeed))+'/s';
StringGrid1.Cells[2,ThreadNo]:=Downloader.StandarizedSize(AReadCount);
if Apercentage=-1 then StringGrid1.Cells[3,ThreadNo]:='Unknown'
else begin
     StringGrid1.Cells[3,ThreadNo]:=Apercentage.ToString+'%';
     ProgresShow.Progresses[ThreadNo]:=Round(APercentage);
     end;
end;

procedure TForm1.ResetDisplay;
var i,j:integer;
begin
Label15.Text:='-';
Label16.Text:='-';
Label18.Text:='-';
Label24.Text:='-';
Label20.Text:='-';
Label22.Text:='-';
Label3.Text:='-';
Label3.TextSettings.FontColor:=TColorRec.Green;
ProgresShow.ResetProgress;
Button1.Tag:=0;
Button1.Text:='Start';
Button2.Tag:=0;
Button2.Text:='Pause';
Button2.Enabled:=False;
ComboBox1.Enabled:=True;
StringGrid1.RowCount:=ComboBox1.Items[ComboBox1.ItemIndex].ToInteger;
for i:=0 to StringGrid1.RowCount-1 do begin
                                      StringGrid1.Cells[0,i]:=(i+1).ToString;
                                      for j:=1 to 3 do StringGrid1.Cells[j,i]:='-';
                                      end;
StringColumn4.Width:=247;
end;

end.
