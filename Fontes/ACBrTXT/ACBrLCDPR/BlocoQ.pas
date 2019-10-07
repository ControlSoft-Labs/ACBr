{******************************************************************************}
{ Projeto: Componente ACBrLCDPR                                                }
{  Biblioteca multiplataforma de componentes Delphi para gera��o do LCDPR -    }
{ Lirvro Caixa Digital do Produtor Rural                                       }
{                                                                              }
{                                                                              }
{ Desenvolvimento e doa��o ao Projeto ACBr: Willian H�bner                     }
{                                                                              }
{ Ajustes e corre��es para doa��o: Elton Barbosa (EMBarbosa)                   }
{                                                                              }
{  Voc� pode obter a �ltima vers�o desse arquivo na pagina do Projeto ACBr     }
{ Componentes localizado em http://www.sourceforge.net/projects/acbr           }
{                                                                              }
{                                                                              }
{  Esta biblioteca � software livre; voc� pode redistribu�-la e/ou modific�-la }
{ sob os termos da Licen�a P�blica Geral Menor do GNU conforme publicada pela  }
{ Free Software Foundation; tanto a vers�o 2.1 da Licen�a, ou (a seu crit�rio) }
{ qualquer vers�o posterior.                                                   }
{                                                                              }
{  Esta biblioteca � distribu�da na expectativa de que seja �til, por�m, SEM   }
{ NENHUMA GARANTIA; nem mesmo a garantia impl�cita de COMERCIABILIDADE OU      }
{ ADEQUA��O A UMA FINALIDADE ESPEC�FICA. Consulte a Licen�a P�blica Geral Menor}
{ do GNU para mais detalhes. (Arquivo LICEN�A.TXT ou LICENSE.TXT)              }
{                                                                              }
{  Voc� deve ter recebido uma c�pia da Licen�a P�blica Geral Menor do GNU junto}
{ com esta biblioteca; se n�o, escreva para a Free Software Foundation, Inc.,  }
{ no endere�o 59 Temple Street, Suite 330, Boston, MA 02111-1307 USA.          }
{ Voc� tamb�m pode obter uma copia da licen�a em:                              }
{ http://www.opensource.org/licenses/lgpl-license.php                          }
{                                                                              }
{ Daniel Sim�es de Almeida  -  daniel@djsystem.com.br  -  www.djsystem.com.br  }
{              Pra�a Anita Costa, 34 - Tatu� - SP - 18270-410                  }
{                                                                              }
{******************************************************************************}
unit BlocoQ;

interface

uses Classes, Contnrs, RegistroQ100, RegistroQ200;

type
  TBlocoQ = Class
  private
    FRegistrosQ100: TRegistroQ100List;
    FRegistroQ200: TRegistroQ200;
    procedure SetRegistroQ200(const Value: TRegistroQ200);
    procedure SetRegistrosQ100(const Value: TRegistroQ100List);
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddRegistroQ100(RegistroQ100 : TRegistroQ100);

    function RegistroQ100New : TRegistroQ100;

    property RegistrosQ100 : TRegistroQ100List read FRegistrosQ100 write SetRegistrosQ100;
    property RegistroQ200 : TRegistroQ200 read FRegistroQ200 write SetRegistroQ200;
  End;

implementation

{ TBlocoQ }

procedure TBlocoQ.AddRegistroQ100(RegistroQ100: TRegistroQ100);
var
  i : integer;
begin
  FRegistrosQ100.Add(TRegistroQ100.Create);
  I := FRegistrosQ100.Count -1;
  FRegistrosQ100[I].DATA        := RegistroQ100.DATA;
  FRegistrosQ100[I].COD_IMOVEL  := RegistroQ100.COD_IMOVEL;
  FRegistrosQ100[I].COD_CONTA   := RegistroQ100.COD_CONTA;
  FRegistrosQ100[I].NUM_DOC     := RegistroQ100.NUM_DOC;
  FRegistrosQ100[I].TIPO_DOC    := RegistroQ100.TIPO_DOC;
  FRegistrosQ100[I].HISTORICO   := RegistroQ100.HISTORICO;
  FRegistrosQ100[I].ID_PARTIC   := RegistroQ100.ID_PARTIC;
  FRegistrosQ100[I].TIPO_LANC   := RegistroQ100.TIPO_LANC;
  FRegistrosQ100[I].VL_ENTRADA  := RegistroQ100.VL_ENTRADA;
  FRegistrosQ100[I].VL_SAIDA    := RegistroQ100.VL_SAIDA;
  FRegistrosQ100[I].SLD_FIN     := RegistroQ100.SLD_FIN;
end;

constructor TBlocoQ.Create;
begin
  FRegistrosQ100 := TRegistroQ100List.Create;
  FRegistroQ200 := TRegistroQ200.Create;
end;

destructor TBlocoQ.Destroy;
begin
  FRegistrosQ100.Destroy;
  FRegistroQ200.Destroy;
  inherited;
end;

function TBlocoQ.RegistroQ100New: TRegistroQ100;
begin
  Result := TRegistroQ100.Create;

  FRegistrosQ100.Add(Result);
end;

procedure TBlocoQ.SetRegistroQ200(const Value: TRegistroQ200);
begin
  FRegistroQ200 := Value;
end;

procedure TBlocoQ.SetRegistrosQ100(const Value: TRegistroQ100List);
begin
  FRegistrosQ100 := Value;
end;

end.
