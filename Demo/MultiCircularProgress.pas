unit MultiCircularProgress;

{********************************************************************************************
   Développer par Faraoun Kamel Mohamed
   Université Djilali Liabes -Sidi Bel Abbes - Algérie
   kamel_mh@yahoo.fr

   Multi-Tracks circular Progressbar. FMX:Windows/Android/Mac...  Just for  Fun
********************************************************************************************}

interface

Uses FMX.Objects,FMX.StdCtrls,System.Classes,System.UITypes,FMX.Types,System.Sysutils,FMX.Graphics;

type
    TTrack=record
            wStart,wEnd,
            wSize:Single;
            Progress:SIngle;
            Arc:TArc;
            Pie:TPie;
            end;
    TMultiCircularProgress=class(TArc)
        private
        FNumofTracks:integer;
        FTracks:array of TTrack;
        FProgressText:TText;
        FProgressBackColor,FProgressColor:TAlphaColor;
        FShowPies,FShowArcs:boolean;
        procedure SetNumOfTracks(Value:integer);
        procedure SetProgresBackColor(Color:TAlphaColor);
        procedure SetProgresColor(Color:TAlphaColor);
        procedure SetProgress(Index:integer; Value: Single);
        function GetProgress(Index:integer):Single;
        procedure SetShowPies(Value:boolean);
        procedure SetShowArcs(Value:boolean);
        function GetTextSettings:TTextSettings;
        procedure SetTextSettings(Value:TTextSettings);
        public
        constructor Create(AOwner: TComponent); override;
        function GetOverallProgress:Double;
        procedure ResetProgress;
        procedure ForceProgressTextValue(wText:string);
        property Progresses[Index: Integer]: single read GetProgress write SetProgress;
        property OverallProgress:Double read GetOverallProgress;
        published
        property NumberOfTracks :integer read  FnumOfTracks write SetNumOfTracks;
        property ProgressBackColor:TAlphaColor read FProgressBackColor write SetProgresBackColor;
        property ProgressColor:TAlphaColor read FProgressColor write SetProgresColor;
        property ShowPies:boolean read FShowPies write SetShowPies;
        property ShowArcs:boolean read FShowArcs write SetShowArcs;
        property ProgressTextSettings:TTextSettings read GetTextSettings write SetTextSettings;
        end;

procedure Register;

implementation

{ TMultiCircularProgress }

///*******************************************************************************************************************************************************//
constructor TMultiCircularProgress.Create(AOwner: TComponent);
begin
  inherited;
Stroke.Thickness:=4;
Stroke.Color:=TAlphaColorRec.White;
FProgressBackColor:=TAlphaColorRec.White;
Height:=140;
Width:=140;
FProgressText:=TText.Create(Self);
FProgressText.Parent:=Self;
FProgressText.Align:=TAlignLayout.Center;
FProgressText.TextSettings.VertAlign:=TTextAlign.Center;
FProgressText.TextSettings.HorzAlign:=TTextAlign.Center;
FProgressText.Text:='0%';
StartAngle:=0;
FNumofTracks:=0;
EndAngle:=360;
FProgressColor:=TAlphaColorRec.Blue;
SetNumOfTracks(4);
Parent:=TFmxObject(AOwner);
FProgressText.BringToFront;
FProgressText.AutoSize:=True;
FProgressText.TextSettings.WordWrap:=False;
FshowPies:=True;
end;

///*******************************************************************************************************************************************************//
function TMultiCircularProgress.GetProgress(Index: integer): Single;
begin
if (Index> Length(FTracks)-1)or(Index<0) then raise Exception.Create('index en dehors des limites .')
else Result:=FTracks[Index].Progress;
end;

function TMultiCircularProgress.GetTextSettings: TTextSettings;
begin
Result:=FProgressText.TextSettings;
end;

///*******************************************************************************************************************************************************//
procedure TMultiCircularProgress.ResetProgress;
var i:integer;
begin
for i:=0 to FNumofTracks-1 do begin
                              FTracks[i].Progress:=0 ;
                              FTracks[i].Arc.EndAngle:=0;
                              FTracks[i].Pie.StartAngle:=0;
                              FTracks[i].Pie.EndAngle:=0;
                              FProgressText.Text:='0%';
                              end;
end;

///*******************************************************************************************************************************************************//
procedure TMultiCircularProgress.ForceProgressTextValue(wText: string);
begin
FProgressText.Text:=wText;
end;

///*******************************************************************************************************************************************************//
function TMultiCircularProgress.GetOverallProgress: Double;
var i:integer;
begin
Result:=0;
for i:=0 to length(FTracks)-1 do Result:=Result+FTracks[i].Progress;
Result:=Round((Result/Length(FTracks))*100)/100;
end;

///*******************************************************************************************************************************************************//
procedure TMultiCircularProgress.SetNumOfTracks(Value: integer);
var i:integer;
begin
for i:=0 to FNumofTracks-1 do begin
                              FTracks[i].Arc.Free;
                              FTracks[i].Pie.Free;
                              end;
FNumofTracks:=Value;
Setlength(FTracks,0);
Setlength(FTracks,Value);
// There is a bug in the implementation of TArc: interpretation of StartAngle and EndAngle is not Correct
// However the interpretation is correct for TPie. As a result, this whill be handled Differently for the two objects.
for i:=0  to Value-1 do begin
                        FTracks[i].Arc:=TArc.Create(Self);
                        FTracks[i].Pie:=TPie.Create(Self);
                        FTracks[i].Arc.Align:=TAlignLayout.Contents;
                        FTracks[i].Pie.Align:=TAlignLayout.Contents;
                        FTracks[i].Arc.Parent:=Self;
                        FTracks[i].Pie.Parent:=Self;
                        FTracks[i].wStart:=i*(360/Value);
                        FTracks[i].wEnd:=(i+1)*(360/Value);
                        FTracks[i].wSize:=FTracks[i].wEnd-FTracks[i].wStart;
                        FTracks[i].Progress:=0;
                        FTracks[i].Pie.StartAngle:=FTracks[i].wStart;
                        FTracks[i].Pie.EndAngle:=FTracks[i].wStart;
                        FTracks[i].Arc.StartAngle:=FTracks[i].Pie.StartAngle+2;
                        FTracks[i].Arc.EndAngle:=0;
                        FTracks[i].Arc.Stroke.Thickness:=4;
                        FTracks[i].Arc.Stroke.Color:=FProgressColor;
                        FTracks[i].Pie.Stroke.Thickness:=0;
                        FTracks[i].Pie.Fill.Color:=FProgressColor;
                        FTracks[i].Pie.Opacity:=0.3;
                        FTracks[i].Pie.Visible:=FShowPies;
                        end;
FNumofTracks:=Length(FTracks);
end;

///*******************************************************************************************************************************************************//
procedure TMultiCircularProgress.SetProgresBackColor(Color: TAlphaColor);
begin
Self.Stroke.Color:=Color;
end;

///*******************************************************************************************************************************************************//
procedure TMultiCircularProgress.SetProgresColor(Color: TAlphaColor);
var i:integer;
begin
for i:=0 to FNumofTracks-1 do begin
                              FTracks[i].Arc.Stroke.Color:=Color;
                              FTracks[i].Pie.Fill.Color:=Color;
                              end;
FProgressColor:=Color;
end;

///*******************************************************************************************************************************************************//
procedure TMultiCircularProgress.SetProgress(Index:integer; Value: Single);
var wProgress:Single;
begin
if (Index> Length(FTracks)-1)or(Index<0) then raise Exception.Create('index en dehors des limites .');
if Value<0 then wProgress:=0
else if Value>100 then wProgress:=100
else wProgress:=Value;
FTracks[Index].Progress:=wProgress;
FTracks[Index].Pie.EndAngle:=FTracks[Index].Pie.StartAngle+(wProgress*FTracks[Index].wSize)/100;
FTracks[Index].Arc.EndAngle:=(wProgress*FTracks[Index].wSize)/100-4;
if FTracks[Index].Arc.EndAngle<0 then FTracks[Index].Arc.EndAngle:=1;
if Value=100  then FTracks[Index].Arc.EndAngle:=FTracks[index].wSize;
FProgressText.Text:=GetOverallProgress.ToString+'%';
end;

///*******************************************************************************************************************************************************//
procedure TMultiCircularProgress.SetShowArcs(Value: boolean);
var i:integer;
begin
FShowArcs:=value;
for i:=0 to NumberOfTracks-1 do FTracks[i].Arc.Visible:=Value;
end;

///*******************************************************************************************************************************************************//
procedure TMultiCircularProgress.SetShowPies(Value: boolean);
var i:integer;
begin
FShowPies:=Value;
for i:=0 to FNumofTracks-1 do FTracks[i].Pie.Visible:=Value;
end;

///*******************************************************************************************************************************************************//
procedure TMultiCircularProgress.SetTextSettings(Value: TTextSettings);
begin
FProgressText.TextSettings.Assign(Value);
end;

procedure Register;
begin
  RegisterComponents('Samples', [TMultiCircularProgress]);
end;

end.
