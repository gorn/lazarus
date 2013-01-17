{
Reads an ODG Document

License: The same modified LGPL as the Free Pascal RTL
         See the file COPYING.modifiedLGPL for more details

An OpenDocument document is a compressed ZIP file with the following files inside:

content.xml     - Actual contents
meta.xml        - Authoring data
settings.xml    - User persistent viewing information, such as zoom, cursor position, etc.
styles.xml      - Styles, which are the only way to do formatting
mimetype        - application/vnd.oasis.opendocument.spreadsheet
META-INF\manifest.xml  - Describes the other files in the archive

Specifications obtained from:

http://docs.oasis-open.org/office/v1.1/OS/OpenDocument-v1.1.pdf

Example of content.xml structure:

<?xml version="1.0" encoding="UTF-8"?>
<office:document-content xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" .....>
<office:scripts/>
<office:automatic-styles>
  <style:style style:name="dp1" style:family="drawing-page"/>
  <style:style style:name="gr1" style:family="graphic" style:parent-style-name="standard">
  ....
</office:automatic-styles>
<office:body>
<office:drawing>
  <draw:page draw:name="page1" draw:style-name="dp1" draw:master-page-name="Oletus">
    <draw:ellipse draw:style-name="gr2" draw:text-style-name="P1" draw:layer="layout" svg:width="11cm" svg:height="3cm" svg:x="5.5cm" svg:y="6.5cm">
      <text:p/>
    </draw:ellipse>
    ... other elements in the page...
  </draw:page>
</office:drawing>
</office:body>
</office:document-content>

AUTHORS: Felipe Monteiro de Carvalho
}
unit odgvectorialreader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, math,
  zipper, {NOTE: fpszipper is the latest zipper.pp Change to standard zipper when FPC 2.8 is released}
  xmlread, DOM, AVL_Tree,
  fpimage, fpcanvas, fgl,
  fpvectorial, fpvutils, lazutf8;

type
{  TSVGTokenType = (
    // moves
    sttMoveTo, sttRelativeMoveTo,
    // Close Path
    sttClosePath,
    // lines
    sttLineTo, sttRelativeLineTo,
    sttHorzLineTo, sttRelativeHorzLineTo, sttVertLineTo, sttRelativeVertLineTo,
    // cubic beziers
    sttBezierTo, sttRelativeBezierTo,
    // quadratic beziers
    sttQuadraticBezierTo, sttRelativeQuadraticBezierTo,
    // Elliptic curves
    sttEllipticArcTo, sttRelativeEllipticArcTo,
    // numbers
    sttFloatValue);

  TSVGToken = class
    TokenType: TSVGTokenType;
    Value: Float;
  end;

  TSVGTokenList = specialize TFPGList<TSVGToken>;

  { TSVGPathTokenizer }

  TSVGPathTokenizer = class
  public
    FPointSeparator, FCommaSeparator: TFormatSettings;
    Tokens: TSVGTokenList;
    constructor Create;
    Destructor Destroy; override;
    procedure AddToken(AStr: string);
    procedure TokenizePathString(AStr: string);
  end;      }

  TODGMasterPage = class
  public
    Name: string;
    PageLayoutName: string;
    StyleName: string;
  end;

  TODGStyle = class(TvEntityWithPenBrushAndFont)
  public
  end;

  TODGPageLayout = class
  public
    Name: string;
    MarginTop, MarginBottom, MarginLeft, MarginRight: Double;
    PageWidth, PageHeight: Double;
  end;

  { TvODGVectorialReader }

  TvODGVectorialReader = class(TvCustomVectorialReader)
  private
    FPointSeparator, FCommaSeparator: TFormatSettings;
    FStyles: TFPList; // of TODGStyle;
    FAutomaticStyles: TFPList; // of TODGStyle;
    FPageLayouts: TFPList; // of TODGPageLayout;
    FMasterPages: TFPList; // of TODGMasterPage;
    //FSVGPathTokenizer: TSVGPathTokenizer;
    //
    procedure DeleteStyle(data,arg:pointer);
    procedure ApplyGraphicAttributeToEntity(ANodeName, ANodeValue: string; ADest: TvEntityWithPen);
    procedure ApplyStyleByNameToEntity(AStyleName: string; ADest: TvEntityWithPen);
    procedure ApplyTextStyleByNameToEntity(AStyleName: string; ADest: TvEntityWithPen);
    procedure ApplyMasterPageToPage(AMasterPageName: string; ADest: TvVectorialPage);
    //
    procedure ReadStyleNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadStyleStyleNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    //
    procedure ReadElement(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadEllipseNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadFrameNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadLineNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadPathNode(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    //
    procedure ReadStylesMasterPage(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    procedure ReadStylesPageLayout(ANode: TDOMNode; AData: TvVectorialPage; ADoc: TvVectorialDocument);
    //
    procedure ParsePathString(AInputStr: string; ADest: TPath);
    procedure GetDrawTransforms(AInputStr: string; out ASkewX, ASkewY, ARotate, ATranslateX, ATranslateY: Double);
    function ReadSVGColor(AValue: string): TFPColor;
    function GetAttrValue(ANode : TDOMNode; AAttrName : string) : string;
    function  StringWithUnitToFloat(AStr: string): Double;
    procedure ConvertODGCoordinatesToFPVCoordinates(
      const AData: TvVectorialPage;
      const ASrcX, ASrcY: Double; var ADestX, ADestY: Double);
    procedure ConvertODGDeltaToFPVDelta(
      const AData: TvVectorialPage;
      const ASrcX, ASrcY: Double; var ADestX, ADestY: Double);
  public
    { General reading methods }
    constructor Create; override;
    Destructor Destroy; override;
    procedure ReadFromStream(AStream: TStream; AData: TvVectorialDocument); override;
    procedure ReadFromFile(AFileName: string; AData: TvVectorialDocument); override;
    procedure ReadFromContentXMLDocument(AXMLDocument: TXMLDocument; AData: TvVectorialDocument);
    procedure ReadFromStylesXMLDocument(AXMLDocument: TXMLDocument; AData: TvVectorialDocument);
  end;

implementation

const
  { OpenDocument general XML constants }
  XML_HEADER           = '<?xml version="1.0" encoding="utf-8" ?>';

  { OpenDocument Directory structure constants }
  OPENDOC_PATH_CONTENT   = 'content.xml';
  OPENDOC_PATH_META      = 'meta.xml';
  OPENDOC_PATH_SETTINGS  = 'settings.xml';
  OPENDOC_PATH_STYLES    = 'styles.xml';
  OPENDOC_PATH_MIMETYPE  = 'mimetype';
  OPENDOC_PATH_METAINF = 'META-INF' + '/';
  OPENDOC_PATH_METAINF_MANIFEST = 'META-INF' + '/' + 'manifest.xml';

  { OpenDocument schemas constants }
  SCHEMAS_XMLNS_OFFICE   = 'urn:oasis:names:tc:opendocument:xmlns:office:1.0';
  SCHEMAS_XMLNS_DCTERMS  = 'http://purl.org/dc/terms/';
  SCHEMAS_XMLNS_META     = 'urn:oasis:names:tc:opendocument:xmlns:meta:1.0';
  SCHEMAS_XMLNS          = 'http://schemas.openxmlformats.org/officeDocument/2006/extended-properties';
  SCHEMAS_XMLNS_CONFIG   = 'urn:oasis:names:tc:opendocument:xmlns:config:1.0';
  SCHEMAS_XMLNS_OOO      = 'http://openoffice.org/2004/office';
  SCHEMAS_XMLNS_MANIFEST = 'urn:oasis:names:tc:opendocument:xmlns:manifest:1.0';
  SCHEMAS_XMLNS_FO       = 'urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0';
  SCHEMAS_XMLNS_STYLE    = 'urn:oasis:names:tc:opendocument:xmlns:style:1.0';
  SCHEMAS_XMLNS_SVG      = 'urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0';
  SCHEMAS_XMLNS_TABLE    = 'urn:oasis:names:tc:opendocument:xmlns:table:1.0';
  SCHEMAS_XMLNS_TEXT     = 'urn:oasis:names:tc:opendocument:xmlns:text:1.0';
  SCHEMAS_XMLNS_V        = 'urn:schemas-microsoft-com:vml';
  SCHEMAS_XMLNS_NUMBER   = 'urn:oasis:names:tc:opendocument:xmlns:datastyle:1.0';
  SCHEMAS_XMLNS_CHART    = 'urn:oasis:names:tc:opendocument:xmlns:chart:1.0';
  SCHEMAS_XMLNS_DR3D     = 'urn:oasis:names:tc:opendocument:xmlns:dr3d:1.0';
  SCHEMAS_XMLNS_MATH     = 'http://www.w3.org/1998/Math/MathML';
  SCHEMAS_XMLNS_FORM     = 'urn:oasis:names:tc:opendocument:xmlns:form:1.0';
  SCHEMAS_XMLNS_SCRIPT   = 'urn:oasis:names:tc:opendocument:xmlns:script:1.0';
  SCHEMAS_XMLNS_OOOW     = 'http://openoffice.org/2004/writer';
  SCHEMAS_XMLNS_OOOC     = 'http://openoffice.org/2004/calc';
  SCHEMAS_XMLNS_DOM      = 'http://www.w3.org/2001/xml-events';
  SCHEMAS_XMLNS_XFORMS   = 'http://www.w3.org/2002/xforms';
  SCHEMAS_XMLNS_XSD      = 'http://www.w3.org/2001/XMLSchema';
  SCHEMAS_XMLNS_XSI      = 'http://www.w3.org/2001/XMLSchema-instance';

  // SVG requires hardcoding a DPI value

  // The Opera Browser and Inkscape use 90 DPI, so we follow that

  // 1 Inch = 25.4 milimiters
  // 90 inches per pixel = (1 / 90) * 25.4 = 0.2822
  // FLOAT_MILIMETERS_PER_PIXEL = 0.3528; // DPI 72 = 1 / 72 inches per pixel

  FLOAT_MILIMETERS_PER_PIXEL = 0.2822; // DPI 90 = 1 / 90 inches per pixel
  FLOAT_PIXELS_PER_MILIMETER = 3.5433; // DPI 90 = 1 / 90 inches per pixel

{ TSVGPathTokenizer }

{constructor TSVGPathTokenizer.Create;
begin
  inherited Create;

  FPointSeparator := DefaultFormatSettings;
  FPointSeparator.DecimalSeparator := '.';
  FPointSeparator.ThousandSeparator := '#';// disable the thousand separator

  Tokens := TSVGTokenList.Create;
end;

destructor TSVGPathTokenizer.Destroy;
begin
  Tokens.Free;

  inherited Destroy;
end;

procedure TSVGPathTokenizer.AddToken(AStr: string);
var
  lToken: TSVGToken;
  lStr: string;
begin
  lToken := TSVGToken.Create;

  lStr := Trim(AStr);
  if lStr = '' then Exit;

  // Moves
  if lStr[1] = 'M' then lToken.TokenType := sttMoveTo
  else if lStr[1] = 'm' then lToken.TokenType := sttRelativeMoveTo
  // Close Path
  else if lStr[1] = 'Z' then lToken.TokenType := sttClosePath
  else if lStr[1] = 'z' then lToken.TokenType := sttClosePath
  // Lines
  else if lStr[1] = 'L' then lToken.TokenType := sttLineTo
  else if lStr[1] = 'l' then lToken.TokenType := sttRelativeLineTo
  else if lStr[1] = 'H' then lToken.TokenType := sttHorzLineTo
  else if lStr[1] = 'h' then lToken.TokenType := sttRelativeHorzLineTo
  else if lStr[1] = 'V' then lToken.TokenType := sttVertLineTo
  else if lStr[1] = 'v' then lToken.TokenType := sttRelativeVertLineTo
  // cubic Bézier curve commands
  else if lStr[1] = 'C' then lToken.TokenType := sttBezierTo
  else if lStr[1] = 'c' then lToken.TokenType := sttRelativeBezierTo
  // quadratic beziers
  else if lStr[1] = 'Q' then lToken.TokenType := sttQuadraticBezierTo
  else if lStr[1] = 'q' then lToken.TokenType := sttRelativeQuadraticBezierTo
  // Elliptic curves
  else if lStr[1] = 'A' then lToken.TokenType := sttEllipticArcTo
  else if lStr[1] = 'a' then lToken.TokenType := sttRelativeEllipticArcTo
  else
  begin
    lToken.TokenType := sttFloatValue;
    lToken.Value := StrToFloat(AStr, FPointSeparator);
  end;

  // Sometimes we get a command glued to a value, for example M150
  if (lToken.TokenType <> sttFloatValue) and (Length(lStr) > 1) then
  begin
    Tokens.Add(lToken);
    lToken.TokenType := sttFloatValue;
    lStr := Copy(AStr, 2, Length(AStr));
    lToken.Value := StrToFloat(lStr, FPointSeparator);
  end;

  Tokens.Add(lToken);
end;

procedure TSVGPathTokenizer.TokenizePathString(AStr: string);
const
  Str_Space: Char = ' ';
  Str_Comma: Char = ',';
var
  i: Integer;
  lTmpStr: string = '';
  lState: Integer;
  lFirstTmpStrChar, lCurChar: Char;
begin
  lState := 0;

  i := 1;
  while i <= Length(AStr) do
  begin
    case lState of
    0: // Adding to the tmp string
    begin
      lCurChar := AStr[i];
      if lCurChar = Str_Space then
      begin
        lState := 1;
        AddToken(lTmpStr);
        lTmpStr := '';
      end
      else if lCurChar = Str_Comma then
      begin
        AddToken(lTmpStr);
        lTmpStr := '';
      end
      else
      begin
        // Check for a break, from letter to number
        if (Length(lTmpStr) >= 1) then
        begin
          lFirstTmpStrChar := lTmpStr[1];
          if ((lFirstTmpStrChar in ['a'..'z', 'A'..'Z']) and not (lCurChar  in ['a'..'z', 'A'..'Z'])) or
             (not (lFirstTmpStrChar in ['a'..'z', 'A'..'Z']) and (lCurChar  in ['a'..'z', 'A'..'Z'])) then
          begin
            AddToken(lTmpStr);
            lTmpStr := '';
            Continue;
          end;
        end;

        lTmpStr := lTmpStr + lCurChar;
      end;

      Inc(i);
    end;
    1: // Removing spaces
    begin
      if AStr[i] <> Str_Space then lState := 0
      else Inc(i);
    end;
    end;
  end;

  // If there is a token still to be added, add it now
  if (lState = 0) and (lTmpStr <> '') then AddToken(lTmpStr);
end;}

procedure TvODGVectorialReader.DeleteStyle(data, arg: pointer);
begin
  TObject(data).Free;
end;

procedure TvODGVectorialReader.ApplyGraphicAttributeToEntity(ANodeName,
  ANodeValue: string; ADest: TvEntityWithPen);
var
  i: Integer;
  lColor: TFPColor;
  lDestBrush: TvEntityWithPenAndBrush absolute ADest;
  lDestFont: TvEntityWithPenBrushAndFont absolute ADest;
begin
  case ANodeName of
  // "none", "solid"
  'draw:fill':
  begin
    if not (ADest is TvEntityWithPenAndBrush) then Exit;
    case ANodeValue of
    'none': lDestBrush.Brush.Style := bsClear;
    'solid': lDestBrush.Brush.Style := bsSolid;
    end;
  end;
  // "#ffffff"
  'draw:fill-color':
  begin
    if not (ADest is TvEntityWithPenAndBrush) then Exit;
    lColor := ReadSVGColor(ANodeValue);
    lDestBrush.Brush.Color := lColor;
  end;
  // Values: "justify", "center", "left"
  'draw:textarea-horizontal-align':
  begin
  end;
  // Values: "middle"
  'draw:textarea-vertical-align':
  begin
  end;
  // true-false
  'draw:auto-grow-height':
  begin
  end;
  // true-false
  'draw:auto-grow-width':
  begin
  end;
  // "none", "dash"
  'draw:stroke':
  begin
    case ANodeValue of
    'none': ADest.Pen.Style := psClear;
    'dash': ADest.Pen.Style := psDash;
    end;
  end;
  // "Fine_20_Dashed_20__28_var_29_"
  'draw:stroke-dash':
  begin
  end;
  // "Arrow"
  'draw:marker-start':
  begin
  end;
  // "0.45cm"
  'draw:marker-start-width':
  begin
  end;
  // "Circle"
  'draw:marker-end':
  begin
  end;
  // "0.45cm"
  'draw:marker-end-width':
  begin
  end;
  // "Transparency_20_1"
  'draw:opacity-name':
  begin
  end;
  // "0.1cm"
  'svg:stroke-width': ADest.Pen.Width := Round(StringWithUnitToFloat(ANodeValue));
  // "#000000"
  'svg:stroke-color': ADest.Pen.Color := ReadSVGColor(ANodeValue);
  // "0cm"
  'fo:min-height':
  begin
  end;
  // "0cm"
  'fo:min-width':
  begin
  end;
  // "wrap"
  'fo:wrap-option':
  begin
  end;
  // "0.175cm"
  'fo:padding-top':
  begin
  end;
  // "0.175cm"
  'fo:padding-bottom':
  begin
  end;
  // "0.3cm"
  'fo:padding-left':
  begin
  end;
  // "0.3cm"
  'fo:padding-right':
  begin
  end;
  end;
end;

// Don't apply font properties here, because there is a separate method for this
procedure TvODGVectorialReader.ApplyStyleByNameToEntity(AStyleName: string;
  ADest: TvEntityWithPen);
var
  i: Integer;
  lCurStyle: TvEntityWithPenBrushAndFont;
begin
  for i := 0 to FStyles.Count-1 do
  begin
    lCurStyle := TvEntityWithPenBrushAndFont(FStyles.Items[i]);
    if lCurStyle.Name = AStyleName then
    begin
      ADest.AssignPen(lCurStyle.Pen);
      if ADest is TvEntityWithPenAndBrush then
        TvEntityWithPenAndBrush(ADest).AssignBrush(lCurStyle.Brush);

      Exit;
    end;
  end;
end;

procedure TvODGVectorialReader.ApplyTextStyleByNameToEntity(AStyleName: string;
  ADest: TvEntityWithPen);
var
  i: Integer;
  lCurStyle: TvEntityWithPenBrushAndFont;
begin
  for i := 0 to FStyles.Count-1 do
  begin
    lCurStyle := TvEntityWithPenBrushAndFont(FStyles.Items[i]);
    if lCurStyle.Name = AStyleName then
    begin
      if ADest is TvEntityWithPenBrushAndFont then
        TvEntityWithPenBrushAndFont(ADest).AssignFont(lCurStyle.Font);

      Exit;
    end;
  end;
end;

procedure TvODGVectorialReader.ApplyMasterPageToPage(AMasterPageName: string;
  ADest: TvVectorialPage);
var
  i: Integer;
  lMasterPage: TODGMasterPage;
  lMasterPageLayout: TODGPageLayout;
begin
  // Find the Master Page
  for i := 0 to FMasterPages.Count-1 do
  begin
    lMasterPage := TODGMasterPage(FMasterPages.Items[i]);
    if lMasterPage.Name = AMasterPageName then Break
    else lMasterPage := nil;
  end;

  if lMasterPage = nil then
    raise Exception.Create(Format('[TvODGVectorialReader.ApplyMasterPageToPage] Master page not found: %s', [AMasterPageName]));

  // Find the Master Page Properties
  for i := 0 to FPageLayouts.Count-1 do
  begin
    lMasterPageLayout := TODGPageLayout(FPageLayouts.Items[i]);
    if lMasterPageLayout.Name = lMasterPage.PageLayoutName then Break
    else lMasterPageLayout := nil;
  end;

  if lMasterPageLayout = nil then
    raise Exception.Create(Format('[TvODGVectorialReader.ApplyMasterPageToPage] Master page layout not found: %s', [lMasterPage.PageLayoutName]));

  ADest.Width := lMasterPageLayout.PageWidth;
  ADest.Height := lMasterPageLayout.PageHeight;
end;

procedure TvODGVectorialReader.ReadStyleNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  Str: String;
begin
  Str := LowerCase(ANode.NodeName);
  case Str of
  'style:style': ReadStyleStyleNode(ANode, AData, ADoc);
  end;
end;

{
<style:style style:name="gr2" style:family="graphic" style:parent-style-name="standard">
  <style:graphic-properties draw:fill="solid" draw:fill-color="#ffff99"
   draw:textarea-horizontal-align="center" draw:textarea-vertical-align="middle"/>
</style:style>
}
procedure TvODGVectorialReader.ReadStyleStyleNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  lStyle: TvEntityWithPenBrushAndFont;
  lGraphicPropertiesNode: TDOMNode;
  i: Integer;
  lNodeName, lNodeValue: DOMString;
begin
  lStyle := TODGStyle.Create;

  // Read attributes of the main style tag
  // <style:style style:name="gr4" style:family="graphic" style:parent-style-name="standard">;
  for i := 0 to lGraphicPropertiesNode.Attributes.Length - 1 do
  begin
    lNodeName := LowerCase(ANode.Attributes.Item[i].NodeName);
    case lNodeName of
    'style:parent-style-name':
    begin
      lNodeValue := LowerCase(ANode.Attributes.Item[i].NodeValue);
      case lNodeValue of
      // "standard"
      'standard': Continue;
      // "objectwithoutfill"
      'objectwithoutfill':
      begin
        lStyle.Brush.Style := bsClear;
      end;
      end;
    end;
    end;
  end;

  // Read graphic properties
  lGraphicPropertiesNode := ANode.FindNode('style:graphic-properties');
  if lGraphicPropertiesNode <> nil then
  begin
    for i := 0 to lGraphicPropertiesNode.Attributes.Length - 1 do
    begin
      lNodeName := LowerCase(lGraphicPropertiesNode.Attributes.Item[i].NodeName);
      lNodeValue := LowerCase(lGraphicPropertiesNode.Attributes.Item[i].NodeValue);
      ApplyGraphicAttributeToEntity(lNodeName, lNodeValue, lStyle);
    end;
  end;
  FStyles.Add(lStyle);
end;

procedure TvODGVectorialReader.ReadElement(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  Str: String;
begin
  Str := LowerCase(ANode.NodeName);
  case Str of
  'draw:ellipse': ReadEllipseNode(ANode, AData, ADoc);
  'draw:frame': ReadFrameNode(ANode, AData, ADoc);
  'draw:line': ReadLineNode(ANode, AData, ADoc);
  'draw:path': ReadPathNode(ANode, AData, ADoc);
  end;
end;

{
  <draw:ellipse
    draw:style-name="gr2" draw:text-style-name="P1" draw:layer="layout"
    svg:width="11cm" svg:height="3cm" svg:x="5.5cm" svg:y="6.5cm">
    <text:p/>
  </draw:ellipse>
}
procedure TvODGVectorialReader.ReadEllipseNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  cx, cy, crx, cry: double;
  lEllipse: TvEllipse;
  i: Integer;
  lNodeName: DOMString;
begin
  cx := 0.0;
  cy := 0.0;
  crx := 0.0;
  cry := 0.0;

  lEllipse := TvEllipse.Create;
  // SVG entities start without any pen drawing, but with a black brush
  lEllipse.Pen.Style := psClear;
  lEllipse.Brush.Style := bsSolid;
  lEllipse.Brush.Color := colBlack;

  // read the attributes
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := ANode.Attributes.Item[i].NodeName;
    if  lNodeName = 'svg:x' then
      cx := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'svg:y' then
      cy := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'svg:width' then
      crx := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue) / 2
    else if lNodeName = 'svg:height' then
      cry := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue) / 2
    else if lNodeName = 'draw:style-name' then
      ApplyStyleByNameToEntity(ANode.Attributes.Item[i].NodeValue, lEllipse)
    else if lNodeName = 'draw:text-style-name' then
      ApplyTextStyleByNameToEntity(ANode.Attributes.Item[i].NodeValue, lEllipse)
    //    else if lNodeName = 'id' then
    //      lEllipse.Name := UTF16ToUTF8(ANode.Attributes.Item[i].NodeValue)
    else
      ApplyGraphicAttributeToEntity(lNodeName, ANode.Attributes.Item[i].NodeValue, lEllipse);
  end;

  // The svg:x and svg:y coordinates are relative to the top-left in ODG,
  // but in fpvectorial we use the center, so correct now
  cx := cx + crx;
  cy := cy + cry;

  ConvertODGCoordinatesToFPVCoordinates(
        AData, cx, cy, lEllipse.X, lEllipse.Y);
  ConvertODGDeltaToFPVDelta(
        AData, crx, cry, lEllipse.HorzHalfAxis, lEllipse.VertHalfAxis);

  AData.AddEntity(lEllipse);
end;

{
<draw:frame draw:style-name="gr12" draw:text-style-name="P2" draw:layer="layout" svg:width="4.5cm" svg:height="1.25cm" svg:x="4cm" svg:y="20cm">
  <draw:text-box><text:p text:style-name="P2"><text:span text:style-name="T1">Kesäyö</text:span></text:p></draw:text-box>
</draw:frame>
}
procedure TvODGVectorialReader.ReadFrameNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
begin

end;

{
<draw:line draw:style-name="gr9" draw:text-style-name="P1" draw:layer="layout"
 svg:x1="14cm" svg:y1="22.5cm" svg:x2="14cm" svg:y2="23.5cm"><text:p/></draw:line>
<draw:line draw:style-name="gr9" draw:text-style-name="P1" draw:layer="layout"
 svg:x1="14cm" svg:y1="23.5cm" svg:x2="13.5cm" svg:y2="25.5cm"><text:p/></draw:line>
}
procedure TvODGVectorialReader.ReadLineNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  x1, y1, x2, y2: double;
  lPath: TPath;
  i: Integer;
  lNodeName: DOMString;
begin
  x1 := 0.0;
  y1 := 0.0;
  x2 := 0.0;
  y2 := 0.0;

  lPath := TPath.Create;

  // read the attributes
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := ANode.Attributes.Item[i].NodeName;
    if  lNodeName = 'svg:x1' then
      x1 := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'svg:y1' then
      y1 := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'svg:x2' then
      x2 := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'svg:y2' then
      y2 := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'draw:style-name' then
      ApplyStyleByNameToEntity(ANode.Attributes.Item[i].NodeValue, lPath)
    else if lNodeName = 'draw:text-style-name' then
      ApplyTextStyleByNameToEntity(ANode.Attributes.Item[i].NodeValue, lPath)
//    else if lNodeName = 'id' then
//      lEllipse.Name := UTF16ToUTF8(ANode.Attributes.Item[i].NodeValue)
    else
      ApplyGraphicAttributeToEntity(lNodeName, ANode.Attributes.Item[i].NodeValue, lPath);
  end;

  ConvertODGCoordinatesToFPVCoordinates(
        AData, x1, y1, x1, y1);
  ConvertODGCoordinatesToFPVCoordinates(
        AData, x2, y2, x2, y2);

  lPath.AppendMoveToSegment(x1, y1);
  lPath.AppendLineToSegment(x2, y2);
  AData.AddEntity(lPath);
end;

{
<draw:path draw:style-name="gr11" draw:text-style-name="P1" draw:layer="layout"
 svg:width="9.429cm" svg:height="4.491cm"
 draw:transform="skewX (-4.3967693286338E-017) rotate (0.417482757076965) translate (6.73314019682066cm 26.0928070675985cm)"
 svg:viewBox="0 0 9430 4492" svg:d="m0 5c688-5 1345-23 2075 66 1374 167-412 989 814 1282 591 141 1129 504 1795 401 694-107 1142 607 1686 945 551 342 1077 719 1509 1195l501 355 549 243 501-238">
 <text:p/></draw:path>
}
procedure TvODGVectorialReader.ReadPathNode(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  x1, y1, x2, y2, lWidth, lHeight: double;
  lPath: TPath;
  i: Integer;
  lNodeName: DOMString;
  lSkewX, lSkewY, lRotate, lTranslateX, lTranslateY: Double;
begin
  x1 := 0.0;
  y1 := 0.0;
  x2 := 0.0;
  y2 := 0.0;
  lWidth := 0.0;
  lHeight := 0.0;

  lPath := TPath.Create;

  // read the attributes
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := ANode.Attributes.Item[i].NodeName;
    if  lNodeName = 'svg:width' then
      lWidth := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'svg:height' then
      lHeight := StringWithUnitToFloat(ANode.Attributes.Item[i].NodeValue)
    else if lNodeName = 'draw:transform' then
      GetDrawTransforms(ANode.Attributes.Item[i].NodeValue, lSkewX, lSkewY, lRotate, lTranslateX, lTranslateY)
    else if lNodeName = 'svg:d' then
      ParsePathString(ANode.Attributes.Item[i].NodeValue, lPath)
    else if lNodeName = 'draw:style-name' then
      ApplyStyleByNameToEntity(ANode.Attributes.Item[i].NodeValue, lPath)
    else if lNodeName = 'draw:text-style-name' then
      ApplyTextStyleByNameToEntity(ANode.Attributes.Item[i].NodeValue, lPath)
//    else if lNodeName = 'id' then
//      lEllipse.Name := UTF16ToUTF8(ANode.Attributes.Item[i].NodeValue)
    else
      ApplyGraphicAttributeToEntity(lNodeName, ANode.Attributes.Item[i].NodeValue, lPath);
  end;

  ConvertODGCoordinatesToFPVCoordinates(
        AData, x1, y1, x1, y1);
  ConvertODGCoordinatesToFPVCoordinates(
        AData, x2, y2, x2, y2);
  ConvertODGDeltaToFPVDelta(
        AData, lWidth, lHeight, lWidth, lHeight);

  AData.AddEntity(lPath);
end;

{
<office:master-styles>
  <style:master-page style:name="Oletus" style:page-layout-name="PM0" draw:style-name="Mdp1"/>
</office:master-styles>
}
procedure TvODGVectorialReader.ReadStylesMasterPage(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  lMasterPage: TODGMasterPage;
  i: Integer;
  lNodeName, lNodeValue: string;
begin
  lMasterPage := TODGMasterPage.Create;

  // Read properties
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := LowerCase(ANode.Attributes.Item[i].NodeName);
    lNodeValue := ANode.Attributes.Item[i].NodeValue;

    case lNodeName of
    'style:name': lMasterPage.Name := lNodeValue;
    'style:page-layout-name': lMasterPage.PageLayoutName := lNodeValue;
    'draw:style-name': lMasterPage.StyleName := lNodeValue;
    end;
  end;
  FMasterPages.Add(lMasterPage);
end;

{
<style:page-layout style:name="PM0">
  <style:page-layout-properties fo:margin-top="1cm" fo:margin-bottom="1cm"
   fo:margin-left="1cm" fo:margin-right="1cm"
   fo:page-width="21cm" fo:page-height="29.7cm"
   style:print-orientation="portrait"/>
</style:page-layout>
}
procedure TvODGVectorialReader.ReadStylesPageLayout(ANode: TDOMNode;
  AData: TvVectorialPage; ADoc: TvVectorialDocument);
var
  lPageLayout: TODGPageLayout;
  lPageLayoutPropertiesNode: TDOMNode;
  i: Integer;
  lNodeName, lNodeValue: string;
begin
  lPageLayout := TODGPageLayout.Create;

  // Read properties
  for i := 0 to ANode.Attributes.Length - 1 do
  begin
    lNodeName := LowerCase(ANode.Attributes.Item[i].NodeName);
    lNodeValue := ANode.Attributes.Item[i].NodeValue;

    case lNodeName of
    'style:name':  lPageLayout.Name := lNodeValue;
    end;
  end;

  // Read properties in the internal item
  lPageLayoutPropertiesNode := ANode.FindNode('style:page-layout-properties');
  if lPageLayoutPropertiesNode <> nil then
  begin
    for i := 0 to lPageLayoutPropertiesNode.Attributes.Length - 1 do
    begin
      lNodeName := LowerCase(lPageLayoutPropertiesNode.Attributes.Item[i].NodeName);
      lNodeValue := lPageLayoutPropertiesNode.Attributes.Item[i].NodeValue;

      case lNodeName of
      'fo:margin-top':  lPageLayout.MarginTop := StringWithUnitToFloat(lNodeValue);
      'fo:margin-bottom':lPageLayout.MarginBottom := StringWithUnitToFloat(lNodeValue);
      'fo:margin-left': lPageLayout.MarginLeft := StringWithUnitToFloat(lNodeValue);
      'fo:margin-right':lPageLayout.MarginRight := StringWithUnitToFloat(lNodeValue);
      'fo:page-width':  lPageLayout.PageWidth := StringWithUnitToFloat(lNodeValue);
      'fo:page-height': lPageLayout.PageHeight := StringWithUnitToFloat(lNodeValue);
      end;
    end;
  end;
  FPageLayouts.Add(lPageLayout);
end;

procedure TvODGVectorialReader.ParsePathString(AInputStr: string; ADest: TPath);
begin

end;

procedure TvODGVectorialReader.GetDrawTransforms(AInputStr: string; out ASkewX,
  ASkewY, ARotate, ATranslateX, ATranslateY: Double);
begin
  ASkewX := 0.0;
  ASkewY := 0.0;
  ARotate := 0.0;
  ATranslateX := 0.0;
  ATranslateY := 0.0;


end;

function TvODGVectorialReader.ReadSVGColor(AValue: string): TFPColor;
var
  lValue, lStr: string;
  lStrings: TStringList;
  i: Integer;
begin
  Result := colBlack;
  lValue := Trim(LowerCase(AValue));

  // Support for rgb(255,255,0)
  if (Length(lValue) > 3) and (Copy(lValue, 0, 3) = 'rgb') then
  begin
    lStrings := TStringList.Create;
    try
      lStr := Copy(lValue, 5, Length(lValue)-5);
      lStrings.Delimiter := ',';
      lStrings.DelimitedText := lStr;
      if lStrings.Count = 3 then
      begin
        Result.Red := StrToInt(lStrings.Strings[0]) * $101;
        Result.Blue := StrToInt(lStrings.Strings[1]) * $101;
        Result.Green := StrToInt(lStrings.Strings[2]) * $101;
      end
      else
        raise Exception.Create(Format('[TvSVGVectorialReader.ReadSVGColor] An unexpected number of channels was found: %d', [lStrings.Count]));
    finally
      lStrings.Free;
    end;
    Exit;
  end;

  // Support for RGB hex
  // ex: #0000ff
  // Another wierd valid variant: #000
  if (Length(lValue) > 1) and (lValue[1] = '#') then
  begin
    lStr := Copy(lValue, 2, 2);
    Result.Red := StrToInt('$'+lStr)*$101;
    lStr := Copy(lValue, 4, 2);
    if lStr = '' then Result.Green := 0
    else Result.Green := StrToInt('$'+lStr)*$101;
    lStr := Copy(lValue, 6, 2);
    if lStr = '' then Result.Blue := 0
    else Result.Blue := StrToInt('$'+lStr)*$101;
    Exit;
  end;

  // Support for named colors
  // List here: http://www.december.com/html/spec/colorsvghex.html
  case lValue of
  'black':   Result := colBlack;
  'navy':    Result.Blue := $8080;
  'darkblue':Result.Blue := $8B8B;
  'mediumblue':Result.Blue := $CDCD;
  'blue':    Result := colBlue;
  'darkgreen':Result.Green := $6464;
  'green':   Result.Green := $8080;
  'teal':
  begin
    Result.Green := $8080;
    Result.Blue := $8080;
  end;
  'darkcyan':
  begin
    Result.Green := $8B8B;
    Result.Blue := $8B8B;
  end;
  'deepskyblue':
  begin
    Result.Green := $BFBF;
    Result.Blue := $FFFF;
  end;
  'darkturquoise':
  begin
    Result.Green := $CECE;
    Result.Blue := $D1D1;
  end;
  'mediumspringgreen':
  begin
    Result.Green := $FAFA;
    Result.Blue := $9A9A;
  end;
  'lime': Result := colGreen;
  'springgreen':
  begin
    Result.Green := $FFFF;
    Result.Blue := $7F7F;
  end;
  'cyan':   Result := colCyan;
  'aqua':   Result := colCyan;
  'midnightblue':
  begin
    Result.Red := $1919;
    Result.Green := $1919;
    Result.Blue := $7070;
  end;
  'dodgerblue':
  begin
    Result.Red := $1E1E;
    Result.Green := $9090;
    Result.Blue := $FFFF;
  end;
  'lightseagreen':
  begin
    Result.Red := $2020;
    Result.Green := $B2B2;
    Result.Blue := $AAAA;
  end;
  'forestgreen':
  begin
    Result.Red := $2222;
    Result.Green := $8B8B;
    Result.Blue := $2222;
  end;
  'seagreen':
  begin
    Result.Red := $2E2E;
    Result.Green := $8B8B;
    Result.Blue := $5757;
  end;
  'darkslategray', 'darkslategrey':
  begin
    Result.Red := $2F2F;
    Result.Green := $4F4F;
    Result.Blue := $4F4F;
  end;
  'limegreen':
  begin
    Result.Red := $3232;
    Result.Green := $CDCD;
    Result.Blue := $3232;
  end;
  'mediumseagreen':
  begin
    Result.Red := $3C3C;
    Result.Green := $CBCB;
    Result.Blue := $7171;
  end;
  'turquoise':
  begin
    Result.Red := $4040;
    Result.Green := $E0E0;
    Result.Blue := $D0D0;
  end;
  'royalblue':
  begin
    Result.Red := $4141;
    Result.Green := $6969;
    Result.Blue := $E1E1;
  end;
  'steelblue':
  begin
    Result.Red := $4646;
    Result.Green := $8282;
    Result.Blue := $B4B4;
  end;
  'darkslateblue':
  begin
    Result.Red := $4848;
    Result.Green := $3D3D;
    Result.Blue := $8B8B;
  end;
  'mediumturquoise':
  begin
    Result.Red := $4848;
    Result.Green := $D1D1;
    Result.Blue := $CCCC;
  end;
{
indigo #4B0082
 	darkolivegreen #556B2F		cadetblue #5F9EA0
cornflowerblue #6495ED
 	mediumaquamarine #66CDAA		dimgrey #696969
dimgray #696969
 	slateblue #6A5ACD		olivedrab #6B8E23
slategrey #708090
 	slategray #708090		lightslategray(Hex3) #778899
lightslategrey(Hex3) #778899
 	mediumslateblue #7B68EE		lawngreen #7CFC00
chartreuse #7FFF00
}
  'aquamarine':
  begin
    Result.Red := $7F7F;
    Result.Green := $FFFF;
    Result.Blue := $D4D4;
  end;
  'maroon': Result.Red := $8080;
  'purple': Result := colPurple;
  'olive':  Result := colOlive;
  'gray', 'grey': Result := colGray;
  'skyblue':
  begin
    Result.Red := $8787;
    Result.Green := $CECE;
    Result.Blue := $EBEB;
  end;
  'lightskyblue':
  begin
    Result.Red := $8787;
    Result.Green := $CECE;
    Result.Blue := $FAFA;
  end;
  'blueviolet':
  begin
    Result.Red := $8A8A;
    Result.Green := $2B2B;
    Result.Blue := $E2E2;
  end;
  'darkred': Result.Red := $8B8B;
  'darkmagenta':
  begin
    Result.Red := $8B8B;
    Result.Blue := $8B8B;
  end;
{
saddlebrown #8B4513
 	darkseagreen #8FBC8F		lightgreen #90EE90
mediumpurple #9370DB
 	darkviolet #9400D3		palegreen #98FB98
darkorchid #9932CC
 	yellowgreen #9ACD32		sienna #A0522D
brown #A52A2A
 	darkgray #A9A9A9		darkgrey #A9A9A9
lightblue #ADD8E6
 	greenyellow #ADFF2F		paleturquoise #AFEEEE
lightsteelblue #B0C4DE
 	powderblue #B0E0E6		firebrick #B22222
darkgoldenrod #B8860B
 	mediumorchid #BA55D3		rosybrown #BC8F8F
darkkhaki #BDB76B
}
  'silver': Result := colSilver;
  'mediumvioletred':
  begin
    Result.Red := $C7C7;
    Result.Green := $1515;
    Result.Blue := $8585;
  end;
  'indianred':
  begin
    Result.Red := $CDCD;
    Result.Green := $5C5C;
    Result.Blue := $5C5C;
  end;
  'peru':
  begin
    Result.Red := $CDCD;
    Result.Green := $8585;
    Result.Blue := $3F3F;
  end;
  'chocolate':
  begin
    Result.Red := $D2D2;
    Result.Green := $6969;
    Result.Blue := $1E1E;
  end;
{
tan #D2B48C
 	lightgray #D3D3D3		lightgrey #D3D3D3
thistle #D8BFD8
 	orchid #DA70D6		goldenrod #DAA520
palevioletred #DB7093
 	crimson #DC143C		gainsboro #DCDCDC
plum #DDA0DD
 	burlywood #DEB887		lightcyan #E0FFFF
lavender #E6E6FA
}
  'darksalmon':
  begin
    Result.Red := $E9E9;
    Result.Green := $9696;
    Result.Blue := $7A7A;
  end;
  'violet':
  begin
    Result.Red := $EEEE;
    Result.Green := $8282;
    Result.Blue := $EEEE;
  end;
  'palegoldenrod':
  begin
    Result.Red := $EEEE;
    Result.Green := $E8E8;
    Result.Blue := $AAAA;
  end;
  'lightcoral':
  begin
    Result.Red := $F0F0;
    Result.Green := $8080;
    Result.Blue := $8080;
  end;
  'khaki':
  begin
    Result.Red := $F0F0;
    Result.Green := $E6E6;
    Result.Blue := $8C8C;
  end;
  'aliceblue':
  begin
    Result.Red := $F0F0;
    Result.Green := $F8F8;
    Result.Blue := $FFFF;
  end;
  'honeydew':
  begin
    Result.Red := $F0F0;
    Result.Green := $FFFF;
    Result.Blue := $F0F0;
  end;
  'azure':
  begin
    Result.Red := $F0F0;
    Result.Green := $FFFF;
    Result.Blue := $FFFF;
  end;
  'sandybrown':
  begin
    Result.Red := $F4F4;
    Result.Green := $A4A4;
    Result.Blue := $6060;
  end;
{
 	wheat #F5DEB3		beige #F5F5DC
whitesmoke #F5F5F5
 	mintcream #F5FFFA		ghostwhite #F8F8FF
salmon #FA8072
 	antiquewhite #FAEBD7		linen #FAF0E6
lightgoldenrodyellow #FAFAD2
 	oldlace #FDF5E6
}
  'red':   Result := colRed;
  'fuchsia':   Result := colFuchsia;
  'magenta':   Result := colMagenta;
{	deeppink #FF1493
orangered #FF4500
 	tomato #FF6347		hotpink #FF69B4
coral #FF7F50
 	darkorange #FF8C00		lightsalmon #FFA07A
orange #FFA500
 	lightpink #FFB6C1		pink #FFC0CB
gold #FFD700
 	peachpuff #FFDAB9		navajowhite #FFDEAD
moccasin #FFE4B5
 	bisque #FFE4C4		mistyrose #FFE4E1
blanchedalmond #FFEBCD
 	papayawhip #FFEFD5		lavenderblush #FFF0F5
seashell #FFF5EE
 	cornsilk #FFF8DC		lemonchiffon #FFFACD
floralwhite #FFFAF0
}
  'snow':
  begin
    Result.Red := $FFFF;
    Result.Green := $FAFA;
    Result.Blue := $FAFA;
  end;
  'yellow': Result := colYellow;
  'lightyellow':
  begin
    Result.Red := $FFFF;
    Result.Green := $FEFE;
  end;
  'ivory':
  begin
    Result.Red := $FFFF;
    Result.Green := $FFFF;
    Result.Blue := $F0F0;
  end;
  'white': Result := colWhite;
  end;
end;

function TvODGVectorialReader.GetAttrValue(ANode : TDOMNode; AAttrName : string) : string;
var
  i : integer;
  Found : Boolean;
begin
  Found:=false;
  i:=0;
  Result:='';
  while not Found and (i<ANode.Attributes.Length) do begin
    if ANode.Attributes.Item[i].NodeName=AAttrName then begin
      Found:=true;
      Result:=ANode.Attributes.Item[i].NodeValue;
    end;
    inc(i);
  end;
end;

function TvODGVectorialReader.StringWithUnitToFloat(AStr: string): Double;
var
  UnitStr, ValueStr: string;
  Len: Integer;
begin
  if AStr = '' then Exit(0.0);

  // Check the unit
  Len := Length(AStr);
  UnitStr := Copy(AStr, Len-1, 2);
  if UnitStr = 'mm' then
  begin
    ValueStr := Copy(AStr, 1, Len-2);
    Result := StrToFloat(ValueStr, FPointSeparator);
  end
  else if UnitStr = 'cm' then
  begin
    ValueStr := Copy(AStr, 1, Len-2);
    Result := StrToFloat(ValueStr, FPointSeparator) * 10;
  end
  else if UnitStr = 'px' then
  begin
    ValueStr := Copy(AStr, 1, Len-2);
    Result := StrToInt(ValueStr);
  end
  else // If there is no unit, just use StrToFloat
  begin
    Result := StrToFloat(AStr, FPointSeparator);
  end;
end;

procedure TvODGVectorialReader.ConvertODGCoordinatesToFPVCoordinates(
  const AData: TvVectorialPage; const ASrcX, ASrcY: Double;
  var ADestX,ADestY: Double);
begin
  ADestX := ASrcX * FLOAT_MILIMETERS_PER_PIXEL;
  ADestY := AData.Height - ASrcY * FLOAT_MILIMETERS_PER_PIXEL;
end;

procedure TvODGVectorialReader.ConvertODGDeltaToFPVDelta(
  const AData: TvVectorialPage; const ASrcX, ASrcY: Double; var ADestX,
  ADestY: Double);
begin
  ADestX := ASrcX * FLOAT_MILIMETERS_PER_PIXEL;
  ADestY := - ASrcY * FLOAT_MILIMETERS_PER_PIXEL;
end;

constructor TvODGVectorialReader.Create;
begin
  inherited Create;

  FPointSeparator := DefaultFormatSettings;
  FPointSeparator.DecimalSeparator := '.';
  FPointSeparator.ThousandSeparator := '#';// disable the thousand separator

//  FSVGPathTokenizer := TSVGPathTokenizer.Create;
  FStyles := TFPList.Create;
  FAutomaticStyles := TFPList.Create;
  FPageLayouts := TFPList.Create;
  FMasterPages := TFPList.Create;
end;

destructor TvODGVectorialReader.Destroy;
begin
  FStyles.ForEachCall(@DeleteStyle, nil);
  FStyles.Free;
  FAutomaticStyles.ForEachCall(@DeleteStyle, nil);
  FAutomaticStyles.Free;
  FPageLayouts.ForEachCall(@DeleteStyle, nil);
  FPageLayouts.Free;
  FMasterPages.ForEachCall(@DeleteStyle, nil);
  FMasterPages.Free;
//  FSVGPathTokenizer.Free;

  inherited Destroy;
end;

procedure TvODGVectorialReader.ReadFromStream(AStream: TStream;
  AData: TvVectorialDocument);
var
  Doc: TXMLDocument;
  lCurNode: TDOMNode;
  lPage: TvVectorialPage;
begin
{  try
    // Read in xml file from the stream
    ReadXMLFile(Doc, AStream);

    // Read the properties of the <svg> tag
    AData.Width := StringWithUnitToFloat(Doc.DocumentElement.GetAttribute('width'));
    AData.Height := StringWithUnitToFloat(Doc.DocumentElement.GetAttribute('height'));

    // Now process the elements
    lCurNode := Doc.DocumentElement.FirstChild;
    lPage := AData.AddPage();
    lPage.Width := AData.Width;
    lPage.Height := AData.Height;
    while Assigned(lCurNode) do
    begin
      ReadEntityFromNode(lCurNode, lPage, AData);
      lCurNode := lCurNode.NextSibling;
    end;
  finally
    // finally, free the document
    Doc.Free;
  end;}
end;

procedure TvODGVectorialReader.ReadFromFile(AFileName: string; AData: TvVectorialDocument);
var
  FilePath : string;
  UnZip : TUnZipper;
  FileList : TStringList;
  Doc : TXMLDocument;
begin
  //unzip content.xml into AFileName path
  FilePath:=GetTempDir(false);
  UnZip:=TUnZipper.Create;
  UnZip.OutputPath:=FilePath;
  FileList:=TStringList.Create;
  FileList.Add('content.xml');
  FileList.Add('styles.xml');
  try
    Unzip.UnZipFiles(AFileName,FileList);
  finally
    FreeAndNil(FileList);
    FreeAndNil(UnZip);
  end; //try

  Doc:=nil;
  try
    // First read the master styles
    ReadXMLFile(Doc,FilePath+'styles.xml');
    DeleteFile(FilePath+'styles.xml');
    ReadFromStylesXMLDocument(Doc, AData);

    // Now process the contents
    ReadXMLFile(Doc,FilePath+'content.xml');
    DeleteFile(FilePath+'content.xml');
    ReadFromContentXMLDocument(Doc, AData);
  finally
    Doc.Free;
  end;
end;

{
<draw:page draw:name="page1" draw:style-name="dp1" draw:master-page-name="Oletus">
}
procedure TvODGVectorialReader.ReadFromContentXMLDocument(
  AXMLDocument: TXMLDocument; AData: TvVectorialDocument);
var
  BodyNode, DrawingNode, PageNode, ElementNode: TDOMNode;
  CurPage: TvVectorialPage;
  i: Integer;
  lNodeName, lNodeValue: String;
begin
  BodyNode := AXMLDocument.DocumentElement.FindNode('office:body');
  if not Assigned(BodyNode) then raise Exception.Create('[TvODGVectorialReader.ReadFromContentXMLDocument] node office:body not found');

  DrawingNode := BodyNode.FindNode('office:drawing');
  if not Assigned(DrawingNode) then raise Exception.Create('[TvODGVectorialReader.ReadFromContentXMLDocument] node office:drawing not found');

  //process each page
  PageNode := DrawingNode.FindNode('draw:page');
  while Assigned(PageNode) do
  begin
    CurPage := aData.AddPage();
    //CurPage..AddWorksheet(GetAttrValue(TableNode,'table:name'));

    //process attributes of the page
    for i := 0 to PageNode.Attributes.Length - 1 do
    begin
      lNodeName := LowerCase(PageNode.Attributes.Item[i].NodeName);
      lNodeValue := PageNode.Attributes.Item[i].NodeValue;
      case lNodeName of
      'draw:master-page-name': ApplyMasterPageToPage(lNodeValue, CurPage);
      end;
    end;

    //process each element inside the page
    ElementNode := PageNode.FirstChild;
    while Assigned(ElementNode) do
    begin
      ReadElement(ElementNode, CurPage, AData);

      ElementNode:=ElementNode.NextSibling;
    end; // while Assigned(ElementNode)

    PageNode:=PageNode.NextSibling;
  end; //while Assigned(PageNode)
end;

procedure TvODGVectorialReader.ReadFromStylesXMLDocument(
  AXMLDocument: TXMLDocument; AData: TvVectorialDocument);
var
  DocStylesNode, AutomaticStylesNode, MasterStylesNode, ElementNode: TDOMNode;
  CurPage: TvVectorialPage;
  i: Integer;
  lNodeName: String;
begin
  DocStylesNode := AXMLDocument.DocumentElement;//.FindNode('office:document-styles');
  if not Assigned(DocStylesNode) then raise Exception.Create('[TvODGVectorialReader.ReadFromStylesXMLDocument] node document-styles not found');

  AutomaticStylesNode := DocStylesNode.FindNode('office:automatic-styles');
  if Assigned(AutomaticStylesNode) then
  begin
    //process each master style
    ElementNode := AutomaticStylesNode.FirstChild;
    while Assigned(ElementNode) do
    begin
      lNodeName := LowerCase(ElementNode.NodeName);
      case lNodeName of
      'style:page-layout': ReadStylesPageLayout(ElementNode, CurPage, AData);
      end;

      ElementNode := ElementNode.NextSibling;
    end; //while Assigned(MasterStyleNode)
  end;

  MasterStylesNode := DocStylesNode.FindNode('office:master-styles');
  if Assigned(MasterStylesNode) then
  begin
    //process each master style
    ElementNode := MasterStylesNode.FirstChild;
    while Assigned(ElementNode) do
    begin
      lNodeName := LowerCase(ElementNode.NodeName);
      case lNodeName of
      'style:master-page': ReadStylesMasterPage(ElementNode, CurPage, AData);
      end;

      ElementNode := ElementNode.NextSibling;
    end; //while Assigned(MasterStyleNode)
  end;
end;

initialization

  RegisterVectorialReader(TvODGVectorialReader, vfODG);

end.
