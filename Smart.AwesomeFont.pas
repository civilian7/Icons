unit Smart.AwesomeFont;

interface

uses
  Winapi.Windows,
  Winapi.GDIPAPI,
  Winapi.GDIPOBJ,
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  Vcl.Graphics;

type
  TFontIcon = class
  strict private
    const
      FONT_COUNT = 16;
      FONT_NAMES: array[0..FONT_COUNT-1] of string = (
        'AntDesign',
        'Entypo',
        'EvilIcons',
        'Feather',
        'FontAwesome',
        'FontAwesome5_Brands',
        'FontAwesome5_Regular',
        'FontAwesome5_Soild',
        'Foundation',
        'IonIcons',
        'MaterialCommunityIcons',
        'MaterialIcons',
        'Octicons',
        'SimpleLineIcons',
        'weathericons',
        'Zocial'
      );
    class var
      FFontCollections: TObjectDictionary<string, TGPPrivateFontCollection>;
      FFontName: TDictionary<string, DWORD>;
      FFontNames: TObjectDictionary<string, TDictionary<string, DWORD>>;

    class constructor Create;
    class destructor Destroy;

    class procedure LoadFontInfo; static;
    class procedure LoadFromResource; static;
  private
    class function  ColorToGPColor(AColor: TColor; Alpha: Byte = 255): Cardinal; static;
    class function  RectToGPRect(ARect: TRect): TGPRectF; static;
  public
    class procedure Draw(ACanvas: TCanvas; AColor: TColor; AColorAlpha: Byte; ARect: TRect; AFontHeight: Integer; AIndex: Integer); overload; static;
    class procedure Draw(AGraphics: TGPGraphics; AColor: Cardinal; ARect: TGPRectF; AFontHeight: Integer; AIndex: Integer); overload; static;
    class function  FindByName(const AName: string): WORD; static;
    class function  GetFontNames: TStrings; static;
  end;

implementation

uses
  System.Math,
  JSONDataObjects;

{$R FontIcons.res}

{ TFontIcon }

class constructor TFontIcon.Create;
begin
  FFontCollections := TObjectDictionary<string, TGPPrivateFontCollection>.Create([doOwnsValues]);
  FFontNames := TObjectDictionary<string, TDictionary<string, DWORD>>.Create([doOwnsValues]);

  LoadFromResource;
end;

class destructor TFontIcon.Destroy;
begin
  FFontCollections.Free;
  FFontNames.Free;
end;

class procedure TFontIcon.Draw(AGraphics: TGPGraphics; AColor: Cardinal; ARect: TGPRectF; AFontHeight, AIndex: Integer);
var
  LFont: TGPFont;
  LBrush: TGPSolidBrush;
  LGPStringFormat: TGPStringFormat;
  LChar: Char;
begin
  if AFontHeight = 0 then
    AFontHeight := Trunc(Min(Trunc(ARect.Width), Trunc(ARect.Height)) * 0.9);

  AGraphics.SetTextRenderingHint(TextRenderingHintAntiAlias);
  LFont := TGPFont.Create('FontAwesome', AFontHeight, FontStyleRegular, UnitPixel, FFontCollection);
  try
    LBrush := TGPSolidBrush.Create(AColor);
    try
      LGPStringFormat := TGPStringFormat.Create;
      try
        LGPStringFormat.SetFormatFlags(StringFormatFlagsNoClip);
        LGPStringFormat.SetAlignment(StringAlignment.StringAlignmentCenter);

        ARect.Y := ARect.Y + (ARect.Height - AFontHeight) / 2;
        ARect.Height := AFontHeight;
        LChar := Chr(AIndex);

        AGraphics.DrawString(LChar, -1, LFont, ARect, LGPStringFormat, LBrush);
      finally
        LGPStringFormat.Free;
      end;
    finally
      LBrush.Free;
    end;
  finally
    LFont.Free;
  end;
end;

class procedure TFontIcon.Draw(ACanvas: TCanvas; AColor: TColor; AColorAlpha: Byte; ARect: TRect; AFontHeight, AIndex: Integer);
var
  LGraphics: TGPGraphics;
  LRect: TGPRectF;
  LColor: Cardinal;
begin
  LGraphics := TGPGraphics.Create(ACanvas.Handle);
  try
    LGraphics.SetSmoothingMode(SmoothingModeHighQuality);
    LGraphics.SetPixelOffsetMode(PixelOffsetModeHalf);

    LColor := ColorToGPColor(AColor, AColorAlpha);
    LRect := RectToGPRect(ARect);

    Draw(LGraphics, LColor, LRect, AFontHeight, AIndex);
  finally
    LGraphics.Free;
  end;
end;

class function TFontIcon.ColorToGPColor(AColor: TColor; Alpha: Byte): Cardinal;
var
  LColor: Cardinal;
begin
  if AColor = clNone then
  begin
    Result := MakeColor(0, 0, 0, 0);
  end
  else
  begin
    LColor := ColorToRGB(AColor);
    Result := ((LColor shl 16) and $00FF0000) or ((LColor shr 16) and $000000FF) or (LColor and $0000FF00) or (Alpha shl 24);
  end;
end;

class function TFontIcon.FindByName(const AName: string): WORD;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to MaxFontCount-1 do
    if SameText(AName, AwesomeFontInfos[i].Name) then
    begin
      Result := AwesomeFontInfos[i].Code;
      Exit;
    end;
end;

class function TFontIcon.GetFontNames: TStrings;
var
  i: Integer;
begin
  Result := TStringList.Create;
  for i := 0 to MaxFontCount-1 do
    Result.Add(AwesomeFontInfos[i].Name);
end;

class procedure TFontIcon.LoadFontInfo;
begin
  LJSON: TJSONObject;
  LStream: TResourceStream;
begin
  LJSON := TJSONObject.Create;
  LStream := TResourceStream.Create(hInstance, 'FONTINFO', RT_RCDATA);
  try
    LJSON.LoadFromStream(LStream);
  finally
    LStream.Free;
  end;
end;

class procedure TFontIcon.LoadFromResource;
var
  i: Integer;
  LFontCollection: TGPFontCollection;
  LFonts: DWord;
  LStatus: TStatus;
  LStream: TResourceStream;
begin
  for i := 0 to FONT_COUNT-1 do
  begin
    LStream := TResourceStream.Create(hInstance, FONT_NAMES[i], RT_RCDATA);
    try
      LFonts := 0;
      AddFontMemResourceEx(LStream.Memory, Cardinal(LStream.Size), nil, @LFonts);

      LFontCollection := TGPFontCollection.Create;
      LStatus := LFontCollection.AddMemoryFont(LStream.Memory, LStream.Size);
      if (LStatus = Status.Ok) then
        FFonts.AddOrSetValue(UpperCase(FONT_NAMES[i]), LFontCollection)
      else
      begin
        LFontCollection.Free;
        RaiseLastOSError();
      end;
    finally
      LStream.Free;
    end;
  end;
end;

class function TFontIcon.RectToGPRect(ARect: TRect): TGPRectF;
begin
  Result.X := ARect.Left;
  Result.Y := ARect.Top;
  Result.Width := ARect.Width;
  Result.Height := ARect.Height;
end;

end.
