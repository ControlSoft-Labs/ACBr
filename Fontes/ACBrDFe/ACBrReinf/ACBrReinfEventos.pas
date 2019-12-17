{******************************************************************************}
{ Projeto: Componente ACBrReinf                                                }
{  Biblioteca multiplataforma de componentes Delphi para envio de eventos do   }
{ Reinf                                                                        }

{ Direitos Autorais Reservados (c) 2017 Leivio Ramos de Fontenele              }
{                                                                              }

{ Colaboradores nesse arquivo:                                                 }

{  Voc� pode obter a �ltima vers�o desse arquivo na pagina do Projeto ACBr     }
{ Componentes localizado em http://www.sourceforge.net/projects/acbr           }


{  Esta biblioteca � software livre; voc� pode redistribu�-la e/ou modific�-la }
{ sob os termos da Licen�a P�blica Geral Menor do GNU conforme publicada pela  }
{ Free Software Foundation; tanto a vers�o 2.1 da Licen�a, ou (a seu crit�rio) }
{ qualquer vers�o posterior.                                                   }

{  Esta biblioteca � distribu�da na expectativa de que seja �til, por�m, SEM   }
{ NENHUMA GARANTIA; nem mesmo a garantia impl�cita de COMERCIABILIDADE OU      }
{ ADEQUA��O A UMA FINALIDADE ESPEC�FICA. Consulte a Licen�a P�blica Geral Menor}
{ do GNU para mais detalhes. (Arquivo LICEN�A.TXT ou LICENSE.TXT)              }

{  Voc� deve ter recebido uma c�pia da Licen�a P�blica Geral Menor do GNU junto}
{ com esta biblioteca; se n�o, escreva para a Free Software Foundation, Inc.,  }
{ no endere�o 59 Temple Street, Suite 330, Boston, MA 02111-1307 USA.          }
{ Voc� tamb�m pode obter uma copia da licen�a em:                              }
{ http://www.opensource.org/licenses/lgpl-license.php                          }
{                                                                              }
{ Leivio Ramos de Fontenele  -  leivio@yahoo.com.br                            }
{******************************************************************************}
{******************************************************************************
|* Historico
|*
|* 24/10/2017: Renato Rubinho
|*  - Compatibilizado Fonte com Delphi 7
*******************************************************************************}

{$I ACBr.inc}

unit ACBrReinfEventos;

interface

uses
  SysUtils, Classes, Contnrs, synautil,
  pcnEventosReinf, pcnConversaoReinf;

type
  TEventos = class;
  TGeradosCollection = class;
  TGeradosCollectionItem = class;

  TGeradosCollection = class(TObjectList)
  private
    function GetItem(Index: Integer): TGeradosCollectionItem;
    procedure SetItem(Index: Integer; Value: TGeradosCollectionItem);
  public
    function Add: TGeradosCollectionItem; overload; deprecated {$IfDef SUPPORTS_DEPRECATED_DETAILS} 'Obsoleta: Use a fun��o New'{$EndIf};
    function New: TGeradosCollectionItem;

    property Items[Index: Integer]: TGeradosCollectionItem read GetItem write SetItem; default;
  end;

  TGeradosCollectionItem = class(TObject)
  private
    FTipoEvento: TTipoEvento;
    FPathNome: String;
    FXML: String;
    FIdEvento: String;
  public
    property TipoEvento: TTipoEvento read FTipoEvento write FTipoEvento;
    property IdEvento: String read FIdEvento write FIdEvento;
    property PathNome: String read FPathNome write FPathNome;
    property XML: String read FXML write FXML;
  end;

  TEventos = class(TComponent)
  private
    FReinfEventos: TReinfEventos;
    FTipoContribuinte: TContribuinte;
    FGerados: TGeradosCollection;

    procedure SetReinfEventos(const Value: TReinfEventos);
    function GetCount: integer;
    procedure SetGerados(const Value: TGeradosCollection);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;//verificar se ser� necess�rio, se TReinfEventos for TComponent;

    procedure GerarXMLs;
    procedure SaveToFiles;
    procedure Clear;

    function LoadFromFile(const CaminhoArquivo: String; ArqXML: Boolean = True): Boolean;
    function LoadFromStream(AStream: TStringStream): Boolean;
    function LoadFromString(const AXMLString: String): Boolean;
    function LoadFromStringINI(const AINIString: String): Boolean;
    function LoadFromIni(const AIniString: String): Boolean;

    property Count:        Integer           read GetCount;
    property ReinfEventos: TReinfEventos     read FReinfEventos     write SetReinfEventos;
    property TipoContribuinte: TContribuinte read FTipoContribuinte write FTipoContribuinte;
    property Gerados: TGeradosCollection     read FGerados          write SetGerados;
  end;

implementation

uses
  dateutils,
  ACBrUtil, ACBrDFeUtil, ACBrReinf;

{ TGeradosCollection }

function TGeradosCollection.Add: TGeradosCollectionItem;
begin
  Result := Self.New;
end;

function TGeradosCollection.GetItem(Index: Integer): TGeradosCollectionItem;
begin
  Result := TGeradosCollectionItem(inherited GetItem(Index));
end;

function TGeradosCollection.New: TGeradosCollectionItem;
begin
  Result := TGeradosCollectionItem.Create;
  Self.Add(Result);
end;

procedure TGeradosCollection.SetItem(Index: Integer;
  Value: TGeradosCollectionItem);
begin
  inherited SetItem(Index, Value);
end;

{ TEventos }

procedure TEventos.Clear;
begin
  FReinfEventos.Clear;
  FGerados.Clear;
end;

constructor TEventos.Create(AOwner: TComponent);
begin
  inherited;

  FReinfEventos := TReinfEventos.Create(AOwner);
  FGerados := TGeradosCollection.Create;
end;

destructor TEventos.Destroy;
begin
  FReinfEventos.Free;
  FGerados.Free;

  inherited;
end;

procedure TEventos.GerarXMLs;
begin
  FTipoContribuinte := TACBrReinf(Self.Owner).Configuracoes.Geral.TipoContribuinte;
  Self.ReinfEventos.GerarXMLs;
end;

function TEventos.GetCount: integer;
begin
  Result :=  Self.ReinfEventos.Count;
end;

procedure TEventos.SaveToFiles;
begin
  // Limpa a lista para n�o ocorrer duplicidades.
  Gerados.Clear;

  Self.ReinfEventos.SaveToFiles;
end;

procedure TEventos.SetGerados(const Value: TGeradosCollection);
begin
  FGerados := Value;
end;

procedure TEventos.SetReinfEventos(const Value: TReinfEventos);
begin
  FReinfEventos.Assign(Value);
end;

function TEventos.LoadFromFile(const CaminhoArquivo: String; ArqXML: Boolean = True): Boolean;
var
  ArquivoXML: TStringList;
  XML: String;
  XMLOriginal: AnsiString;
begin
  ArquivoXML := TStringList.Create;
  try
    ArquivoXML.LoadFromFile(CaminhoArquivo);
    XMLOriginal := ArquivoXML.Text;
  finally
    ArquivoXML.Free;
  end;

  // Converte de UTF8 para a String nativa da IDE //
  XML := DecodeToString(XMLOriginal, True);

  if ArqXML then
    Result := LoadFromString(XML)
  else
    Result := LoadFromStringINI(XML);
end;

function TEventos.LoadFromStream(AStream: TStringStream): Boolean;
var
  XMLOriginal: AnsiString;
begin
  AStream.Position := 0;
  XMLOriginal := ReadStrFromStream(AStream, AStream.Size);

  Result := Self.LoadFromString(String(XMLOriginal));
end;

function TEventos.LoadFromString(const AXMLString: String): Boolean;
var
  AXML, AXMLStr: String;
  P: integer;

  function PosReinf: integer;
  begin
    Result := pos('</Reinf>', AXMLStr);
  end;

begin
  Result := False;
  AXMLStr := AXMLString;
  P := PosReinf;

  while P > 0 do
  begin
    AXML := copy(AXMLStr, 1, P + 7);
    AXMLStr := Trim(copy(AXMLStr, P + 8, length(AXMLStr)));

    Result := Self.ReinfEventos.LoadFromString(AXML);
    SaveToFiles;

    P := PosReinf;
  end;
end;

function TEventos.LoadFromStringINI(const AINIString: String): Boolean;
begin
  Result := Self.ReinfEventos.LoadFromIni(AIniString);
  SaveToFiles;
end;

function TEventos.LoadFromIni(const AIniString: String): Boolean;
begin
  // O valor False no segundo par�metro indica que o conteudo do arquivo n�o �
  // um XML.
  Result := LoadFromFile(AIniString, False);
end;

end.
