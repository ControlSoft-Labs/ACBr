{******************************************************************************}
{ Projeto: Componente ACBrNFe                                                  }
{ Biblioteca multiplataforma de componentes Delphi para emiss�o de Nota Fiscal }
{ eletr�nica - NFe - http://www.nfe.fazenda.gov.br                             }

{ Direitos Autorais Reservados (c) 2015 Daniel Simoes de Almeida               }
{ Andr� Ferreira de Moraes                                                     }

{ Colaboradores nesse arquivo:                                                 }

{ Voc� pode obter a �ltima vers�o desse arquivo na pagina do Projeto ACBr      }
{ Componentes localizado em http://www.sourceforge.net/projects/acbr           }

{ Esta biblioteca � software livre; voc� pode redistribu�-la e/ou modific�-la  }
{ sob os termos da Licen�a P�blica Geral Menor do GNU conforme publicada pela  }
{ Free Software Foundation; tanto a vers�o 2.1 da Licen�a, ou (a seu crit�rio) }
{ qualquer vers�o posterior.                                                   }

{ Esta biblioteca � distribu�da na expectativa de que seja �til, por�m, SEM    }
{ NENHUMA GARANTIA; nem mesmo a garantia impl�cita de COMERCIABILIDADE OU      }
{ ADEQUA��O A UMA FINALIDADE ESPEC�FICA. Consulte a Licen�a P�blica Geral Menor}
{ do GNU para mais detalhes. (Arquivo LICEN�A.TXT ou LICENSE.TXT)              }

{ Voc� deve ter recebido uma c�pia da Licen�a P�blica Geral Menor do GNU junto }
{ com esta biblioteca; se n�o, escreva para a Free Software Foundation, Inc.,  }
{ no endere�o 59 Temple Street, Suite 330, Boston, MA 02111-1307 USA.          }
{ Voc� tamb�m pode obter uma copia da licen�a em:                              }
{ http://www.opensource.org/licenses/lgpl-license.php                          }

{ Daniel Sim�es de Almeida  -  daniel@djsystem.com.br  -  www.djsystem.com.br  }
{ Pra�a Anita Costa, 34 - Tatu� - SP - 18270-410                               }

{******************************************************************************}

{$I ACBr.inc}

unit ACBrDFeXsLibXml2;

interface

uses
  Classes, SysUtils,
  ACBrDFeSSL, libxml2;

const
  cErrParseDoc = 'Erro: Falha ao interpretar o XML "xmlParseDoc"';
  cErrFindSignNode = 'Erro: Falha ao localizar o n� de Assinatura';
  cErrFindRootNode = 'Erro: Falha ao localizar o n� Raiz';
  cErrC14NTransformation = 'Erro ao aplicar transforma��o C14N';
  cErrElementsNotFound = 'Nenhum elemento encontrado';
  cErrDigestValueNode = 'Node DigestValue n�o encontrado';
  cErrSignatureValueNode = 'Node SignatureValue n�o encontrado';
  cErrDigestValueNaoConfere = 'DigestValue n�o confere. Conte�do de "%s" foi alterado';
  cSignatureNode = 'Signature';
  cSignatureNameSpace = 'http://www.w3.org/2000/09/xmldsig#';
  cDigestValueNode = 'DigestValue';
  cSignedInfoNode = 'SignedInfo';
  cSignatureValueNode = 'SignatureValue';
  cX509CertificateNode = 'X509Certificate';

type

  { TDFeSSLXmlSignLibXml2 }

  TDFeSSLXmlSignLibXml2 = class(TDFeSSLXmlSignClass)
  private
  protected
    procedure VerificarValoresPadrao(var SignatureNode: String;
      var SelectionNamespaces: String); virtual;
    function SelectElements(const aDoc: xmlDocPtr; const infElement: String)
      : xmlNodeSetPtr;
    function CanonC14n(const aDoc: xmlDocPtr; const infElement: String): String;
    function LibXmlFindSignatureNode(aDoc: xmlDocPtr;
      var SignatureNode: String; var SelectionNamespaces: String;
      infElement: String): xmlNodePtr;
    function LibXmlLookUpNode(ParentNode: xmlNodePtr; NodeName: String;
      NameSpace: String = ''): xmlNodePtr;
    function LibXmlNodeWasFound(ANode: xmlNodePtr; NodeName: String;
      NameSpace: String): boolean;
    function LibXmlEstaAssinado(const ConteudoXML: String;
      SignatureNode, SelectionNamespaces, infElement: String): boolean;
  public
    function Assinar(const ConteudoXML, docElement, infElement: String;
      SignatureNode: String = ''; SelectionNamespaces: String = '';
      IdSignature: String = ''; IdAttr: String = ''): String; override;
    function Validar(const ConteudoXML, ArqSchema: String; out MsgErro: String)
      : boolean; override;
    function VerificarAssinatura(const ConteudoXML: String; out MsgErro: String;
      const infElement: String; SignatureNode: String = '';
      SelectionNamespaces: String = ''; IdSignature: String = '';
      IdAttr: String = ''): boolean; override;
  end;

procedure LibXmlInit();
procedure LibXmlShutDown();

implementation

uses
  synacode,
  ACBrUtil, ACBrConsts, ACBrDFeException;

var
  LibXMLLoaded: boolean;

  { TDFeSSLXmlSignLibXml2 }

procedure LibXmlInit;
begin
  if (LibXMLLoaded) then
    Exit;

  // --Inicializar fun��es das units do libxml2
  libxml2.Init;

  { Init libxml and libxslt libraries }
  xmlInitThreads();
  xmlInitParser();
  xmlSubstituteEntitiesDefault(1);
  __xmlLoadExtDtdDefaultValue^ := XML_DETECT_IDS or XML_COMPLETE_ATTRS;
  __xmlIndentTreeOutput^ := 1;
  __xmlSaveNoEmptyTags^ := 1;

  LibXMLLoaded := True;
end;

procedure LibXmlShutDown();
begin
  if (not LibXMLLoaded) then
    Exit;

  { Shutdown libxslt/libxml }
  xmlCleanupParser();

  LibXMLLoaded := False;
end;

function TDFeSSLXmlSignLibXml2.Assinar(const ConteudoXML, docElement,
  infElement: String; SignatureNode: String; SelectionNamespaces: String;
  IdSignature: String; IdAttr: String): String;
var
  aDoc: xmlDocPtr;
  SignNode, XmlNode: xmlNodePtr;
  buffer: PAnsiChar;
  aXML, XmlAss: String;
  Canon, DigestValue, Signaturevalue: AnsiString;
  TemDeclaracao: Boolean;
  XmlLength: Integer;
begin
  LibXmlInit;

  XmlAss := '';
  // Verificando se possui a Declara��o do XML, se n�o possuir,
  // adiciona para libXml2 compreender o Encoding
  TemDeclaracao := XmlEhUTF8(ConteudoXML);
  if not TemDeclaracao then
    aXML := CUTF8DeclaracaoXML + RemoverDeclaracaoXML(ConteudoXML)
  else
    aXML := ConteudoXML;

  // Inserindo Template da Assinatura digital
  if (not LibXmlEstaAssinado(aXML, SignatureNode, SelectionNamespaces, infElement)) then
    aXML := AdicionarSignatureElement(aXML, True, docElement, IdSignature, IdAttr);

  aDoc := nil;
  buffer := nil;
  XmlLength := 0;
  try
    aDoc := xmlParseDoc(PAnsiChar(AnsiString(aXML)));
    if (aDoc = nil) then
      raise EACBrDFeException.Create(cErrParseDoc);

    SignNode := LibXmlFindSignatureNode(aDoc, SignatureNode, SelectionNamespaces, infElement);
    if (SignNode = nil) then
      raise EACBrDFeException.Create(cErrFindSignNode);

    // DEBUG
    // WriteToTXT('C:\TEMP\XmlSign.xml', aXML, False, False);

    // Aplica a transforma��o c14n no node infElement
    Canon := AnsiString(CanonC14n(aDoc, infElement));

    // DEBUG
    // WriteToTXT('C:\TEMP\CanonDigest.xml', Canon, False, False);

    // gerar o hash
    DigestValue := FpDFeSSL.CalcHash(Canon, FpDFeSSL.SSLDgst, outBase64);

    XmlNode := LibXmlLookUpNode(SignNode, cDigestValueNode);
    if (XmlNode = nil) then
      raise EACBrDFeException.Create(cErrDigestValueNode);

    xmlNodeSetContent(XmlNode, PAnsiChar(DigestValue));

    // DEBUG
    // buffer := nil;
    // xmlDocDumpMemory(aDoc, @buffer, @XmlLength);
    // WriteToTXT('C:\TEMP\DigestXml.xml', buffer, False, False);

    // Aplica a transforma��o c14n o node SignedInfo
    Canon := AnsiString(CanonC14n(aDoc, cSignedInfoNode));

    // DEBUG
    // WriteToTXT('C:\TEMP\CanonGeracao.xml', Canon, False, False);

    // Assina o node SignedInfo j� transformado
    Signaturevalue := FpDFeSSL.CalcHash(Canon, FpDFeSSL.SSLDgst, outBase64, True);

    XmlNode := LibXmlLookUpNode(SignNode, cSignatureValueNode);
    if (XmlNode = nil) then
      raise EACBrDFeException.Create(cErrSignatureValueNode);

    xmlNodeSetContent(XmlNode, PAnsiChar(Signaturevalue));

    XmlNode := LibXmlLookUpNode(SignNode, cX509CertificateNode);
    if (XmlNode = nil) then
      raise EACBrDFeException.Create('X509Certificate n�o encontrado.');

    xmlNodeSetContent(XmlNode, PAnsiChar(AnsiString(FpDFeSSL.DadosCertificado.DERBase64)));

    xmlDocDumpMemory(aDoc, @buffer, @XmlLength);
    XmlAss := String(buffer);

    // DEBUG
    // WriteToTXT('C:\TEMP\XmlSigned.xml', XmlAss, False, False);
  finally
    if (buffer <> nil) then
      xmlFree(buffer);

    if (aDoc <> nil) then
      xmlFreeDoc(aDoc);
  end;

  if not TemDeclaracao then
    XmlAss := RemoverDeclaracaoXML(XmlAss);

  // Removendo quebras de linha //
  XmlAss := ChangeLineBreak(XmlAss, '');

  // DEBUG
  // WriteToTXT('C:\TEMP\XmlSigned2.xml', XmlAss, False, False);

  Result := XmlAss;
end;

function TDFeSSLXmlSignLibXml2.CanonC14n(const aDoc: xmlDocPtr;
  const infElement: String): String;
var
  Elements: xmlNodeSetPtr;
  buffer: PAnsiChar;
begin
  Result := '';
  buffer := Nil;

  try
    // seleciona os elementos a serem transformados e inclui os devidos namespaces
    Elements := SelectElements(aDoc, infElement);

    // Estamos aplicando a vers�o 1.0 do c14n, mas existe a vers�o 1.1
    // Talvez seja necessario no futuro checar a vers�o do c14n
    // aplica a transforma��o C14N
    if xmlC14NDocDumpMemory(aDoc, Elements, xmlC14NMode.XML_C14N_1_0, nil, 0, @buffer) < 0 then
      raise EACBrDFeException.Create(cErrC14NTransformation);

    if buffer = Nil then
      raise EACBrDFeException.Create(cErrC14NTransformation);

    Result := String(buffer);
    // DEBUG
    // WriteToTXT('C:\TEMP\CanonC14n.xml', Result, False, False);
  finally
    if (Elements <> Nil) then
      xmlXPathFreeNodeSet(Elements);

    if (buffer <> Nil) then
      xmlFree(buffer);
  end;
end;

function TDFeSSLXmlSignLibXml2.SelectElements(const aDoc: xmlDocPtr;
  const infElement: String): xmlNodeSetPtr;
var
  xpathCtx: xmlXPathContextPtr;
  xpathExpr: AnsiString;
  xpathObj: xmlXPathObjectPtr;
begin
  // Cria o contexdo o XPath
  xpathCtx := xmlXPathNewContext(aDoc);
  try
    if (xpathCtx = nil) then
      raise EACBrDFeException.Create('Erro ao obter o contexto do XPath');

    // express?o para selecionar os elementos n: ? o namespace selecionado
    xpathExpr := '(//.|//@*|//namespace::*)[ancestor-or-self::*[local-name()='''
      + infElement + ''']]';

    // seleciona os elementos baseados na express�o(retorna um objeto XPath com os elementos)
    xpathObj := xmlXPathEvalExpression(PAnsiChar(xpathExpr), xpathCtx);

    if (xpathObj = nil) then
      raise EACBrDFeException.Create
        (ACBrStr('Erro ao selecionar os elementos do XML.'));

    if (xpathObj.nodesetval.nodeNr > 0) then
      Result := xpathObj.nodesetval
    else
      raise EACBrDFeException.Create(cErrElementsNotFound);

  finally
    if (xpathCtx <> nil) then
      xmlXPathFreeContext(xpathCtx);
  end;
end;

function TDFeSSLXmlSignLibXml2.Validar(const ConteudoXML, ArqSchema: String;
  out MsgErro: String): boolean;
var
  doc, schema_doc: xmlDocPtr;
  parser_ctxt: xmlSchemaParserCtxtPtr;
  schema: xmlSchemaPtr;
  valid_ctxt: xmlSchemaValidCtxtPtr;
  schemError: xmlErrorPtr;
begin
  LibXmlInit;

  Result := False;
  MsgErro := '';

  doc := nil;
  schema_doc := nil;
  parser_ctxt := nil;
  schema := nil;
  valid_ctxt := nil;

  try
    doc := xmlParseDoc(PAnsiChar(AnsiString(ConteudoXML)));
    if ((doc = nil) or (xmlDocGetRootElement(doc) = nil)) then
    begin
      MsgErro := cErrParseDoc;
      Exit;
    end;

    schema_doc := xmlReadFile(PAnsiChar(ansistring(ArqSchema)), nil, XML_DETECT_IDS);
    // the schema cannot be loaded or is not well-formed
    if (schema_doc = nil) then
    begin
      MsgErro := 'Erro: Schema n�o pode ser carregado ou est� corrompido';
      Exit;
    end;

    parser_ctxt := xmlSchemaNewDocParserCtxt(schema_doc);
    // unable to create a parser context for the schema */
    if (parser_ctxt = nil) then
    begin
      MsgErro := 'Erro: N�o foi possivel criar um contexto para o Schema';
      Exit;
    end;

    schema := xmlSchemaParse(parser_ctxt);
    // the schema itself is not valid
    if (schema = nil) then
    begin
      MsgErro := 'Erro: Schema inv�lido';
      Exit;
    end;

    valid_ctxt := xmlSchemaNewValidCtxt(schema);
    // unable to create a validation context for the schema */
    if (valid_ctxt = nil) then
    begin
      MsgErro := 'Error: n�o foi possivel criar um contexto de valida��o para o Schema';
      Exit;
    end;

    if (xmlSchemaValidateDoc(valid_ctxt, doc) <> 0) then
    begin
      schemError := xmlGetLastError();
      if (schemError <> nil) then
        MsgErro := IntToStr(schemError^.code) + ' - ' + schemError^.message
      else
        MsgErro := 'Erro indefinido, ao validar o Documento com o Schema';
    end
    else
      Result := True;

  finally
    { cleanup }
    if (doc <> nil) then
      xmlFreeDoc(doc);

    if (schema_doc <> nil) then
      xmlFreeDoc(schema_doc);

    if (parser_ctxt <> nil) then
      xmlSchemaFreeParserCtxt(parser_ctxt);

    if (valid_ctxt <> nil) then
      xmlSchemaFreeValidCtxt(valid_ctxt);

    if (schema <> nil) then
      xmlSchemaFree(schema);
  end;
end;

function TDFeSSLXmlSignLibXml2.VerificarAssinatura(const ConteudoXML: String;
  out MsgErro: String; const infElement: String; SignatureNode: String;
  SelectionNamespaces: String; IdSignature: String; IdAttr: String): boolean;
var
  aDoc: xmlDocPtr;
  SignElement: String;
  DigestXML,  DigestCalc, XmlSign, X509Certificate, CanonXML: AnsiString;
  signBuffer: xmlBufferPtr;
  DigestAlg: TSSLDgst;
  rootNode, SignNode: xmlNodePtr;
begin
  LibXmlInit;

  Result := False;
  signBuffer := nil;
  aDoc := nil;

  try
    aDoc := xmlParseDoc(PAnsiChar(AnsiString(ConteudoXML)));
    if (aDoc = nil) then
    begin
       MsgErro := cErrParseDoc;
       Exit;
    end;

    rootNode := xmlDocGetRootElement(aDoc);
    if (rootNode = nil) then
    begin
       MsgErro := cErrFindRootNode;
       Exit;
    end;

    SignNode := LibXmlFindSignatureNode(aDoc, SignatureNode, SelectionNamespaces, infElement);
    if (SignNode.Name <> SignatureNode) then
    if (rootNode = nil) then
    begin
       MsgErro := cErrFindSignNode;
       Exit;
    end;

    signBuffer := xmlBufferCreate();
    xmlNodeDump(signBuffer, aDoc, SignNode, 0, 0);
    SignElement := String(signBuffer.content);

    DigestXML := DecodeBase64(AnsiString(LerTagXML(SignElement, cDigestValueNode)));
    DigestAlg := GetSignDigestAlgorithm(SignElement);

    // Estamos aplicando a vers�o 1.0 do c14n, mas existe a vers�o 1.1
    // Talvez seja necessario no futuro checar a vers�o do c14n
    // para poder validar corretamente
    // Recalculando o DigestValue do XML e comparando com o atual
    CanonXML := AnsiString(CanonC14n(aDoc, infElement));
    if(not FpDFeSSL.ValidarHash(CanonXML, DigestAlg, DigestXML)) then
    begin
       MsgErro := Format(cErrDigestValueNaoConfere, [infElement]);
       Exit;
    end;

    X509Certificate := AnsiString(LerTagXML(SignElement, cX509CertificateNode));
    FpDFeSSL.CarregarCertificadoPublico(X509Certificate);

    CanonXML := AnsiString(CanonC14n(aDoc, cSignedInfoNode));

    XmlSign := DecodeBase64( AnsiString(LerTagXML(SignElement, cSignatureValueNode)) );
    Result := FpDFeSSL.ValidarHash(CanonXML, DigestAlg, XmlSign, True);
  finally
    { cleanup }
    if (aDoc <> nil) then
      xmlFreeDoc(aDoc);

    if (signBuffer <> nil) then
      xmlBufferFree(signBuffer);

    // Descarrega o Certificado Publico //
    FpDFeSSL.DescarregarCertificado;
  end;
end;

procedure TDFeSSLXmlSignLibXml2.VerificarValoresPadrao(var SignatureNode
  : String; var SelectionNamespaces: String);
begin
  if (SignatureNode <> cSignatureNode) then
    SignatureNode := cSignatureNode;

  if (SelectionNamespaces <> cSignatureNameSpace) then
    SelectionNamespaces := cSignatureNameSpace;
end;

function TDFeSSLXmlSignLibXml2.LibXmlFindSignatureNode(aDoc: xmlDocPtr;
  var SignatureNode: String; var SelectionNamespaces: String; infElement: String
  ): xmlNodePtr;
var
  rootNode, infNode, SignNode: xmlNodePtr;
begin
  { Encontra o elemento Raiz }
  rootNode := xmlDocGetRootElement(aDoc);
  if (rootNode = nil) then
    raise EACBrDFeException.Create(cErrFindRootNode);

  VerificarValoresPadrao(SignatureNode, SelectionNamespaces);

  { Se infElement possui prefixo o mesmo tem que ser removido }
  if Pos(':', infElement) > 0 then
    infElement := copy(infElement, Pos(':', infElement) + 1, Length(infElement));

  { Se tem InfElement, procura pelo mesmo. Isso permitir� acharmos o n� de
    assinatura, relacionado a ele (mesmo pai) }
  if (infElement <> '') then
  begin
    { Procura InfElement em todos os n�s, filhos de Raiz, usando LibXml }
    infNode := LibXmlLookUpNode(rootNode, infElement);

    { N�o achei o InfElement em nenhum n� :( }
    if (infNode = nil) then
      raise EACBrDFeException.Create(cErrFindRootNode);

    { Vamos agora, achar o pai desse Elemento, pois com ele encontraremos a assinatura }
    if (infNode^.Name = infElement) and
       Assigned(infNode^.parent) and
       (infNode^.parent^.Name <> '') then
    begin
      infNode := infNode^.parent;
    end;
  end
  else
  begin
    { InfElement n�o foi informado... vamos usar o n� raiz, para pesquisar pela assinatura }
    infNode := rootNode;
  end;

  if (infNode = nil) then
    raise EACBrDFeException.Create(cErrFindRootNode);

  { Procurando pelo n� de assinatura...
    Primeiro vamos verificar manualmente se � o �ltimo no do nosso infNode atual };
  SignNode := infNode^.last;
  if not LibXmlNodeWasFound(SignNode, SignatureNode, SelectionNamespaces) then
  begin
    { N�o � o ultimo n� do infNode... ent�o, vamos procurar por um N� dentro de infNode }
    SignNode := LibXmlLookUpNode(infNode, SignatureNode, SelectionNamespaces);

    { Se ainda n�o achamos, vamos procurar novamente a partir do elemento Raiz }
    if (SignNode = nil) then
    begin
      SignNode := rootNode^.last;
      if not LibXmlNodeWasFound(SignNode, SignatureNode, SelectionNamespaces) then
        SignNode := LibXmlLookUpNode(rootNode, SignatureNode, SelectionNamespaces);
    end;
  end;

  if (SignNode = nil) then
    raise EACBrDFeException.Create(cErrFindSignNode);

  Result := SignNode;
end;

function TDFeSSLXmlSignLibXml2.LibXmlNodeWasFound(ANode: xmlNodePtr;
  NodeName: String; NameSpace: String): boolean;
begin
  Result := (ANode <> nil) and (ANode^.Name = NodeName) and
    ((NameSpace = '') or (ANode^.ns^.href = NameSpace));
end;

function TDFeSSLXmlSignLibXml2.LibXmlLookUpNode(ParentNode: xmlNodePtr;
  NodeName: String; NameSpace: String): xmlNodePtr;

  function _LibXmlLookUpNode(ParentNode: xmlNodePtr; NodeName: String;
    NameSpace: String): xmlNodePtr;
  var
    NextNode, ChildNode, FoundNode: xmlNodePtr;
  begin
    Result := ParentNode;
    if (ParentNode = nil) then
      Exit;

    FoundNode := ParentNode;

    while (FoundNode <> nil) and
      (not LibXmlNodeWasFound(FoundNode, NodeName, NameSpace)) do
    begin
      ChildNode := FoundNode^.children;
      NextNode := FoundNode^.Next;
      { Faz Chamada recursiva para o novo Filho }
      FoundNode := _LibXmlLookUpNode(ChildNode, NodeName, NameSpace);

      if FoundNode = nil then
        FoundNode := NextNode;
    end;

    Result := FoundNode;
  end;

begin
  Result := ParentNode;
  if (ParentNode = nil) or (Trim(NodeName) = '') then
    Exit;

  { Primeiro vamos ver se o n� Raiz j� n�o � o que precisamos }
  if LibXmlNodeWasFound(ParentNode, NodeName, NameSpace) then
    Exit;

  { Chama fun��o auxiliar, que usa busca recursiva em todos os n�s filhos }
  Result := _LibXmlLookUpNode(ParentNode^.children, NodeName, NameSpace);
end;

function TDFeSSLXmlSignLibXml2.LibXmlEstaAssinado(const ConteudoXML: String;
  SignatureNode, SelectionNamespaces, infElement: String): boolean;
var
  aDoc: xmlDocPtr;
  SignNode: xmlNodePtr;
begin
  LibXmlInit;
  Result := False;

  aDoc := nil;
  SignNode := nil;

  try
    aDoc := xmlParseDoc(PAnsiChar(AnsiString(ConteudoXML)));
    if (aDoc = nil) then
      Exit;

    try
      SignNode := LibXmlFindSignatureNode(aDoc, SignatureNode, SelectionNamespaces, infElement);
    except
      // Ignorar exception
    end;

    if ((SignNode <> nil) and (SignNode^.Name = SignatureNode)) then
      Result := True;
  finally
    if (aDoc <> nil) then
      xmlFreeDoc(aDoc);
  end;
end;

initialization

LibXMLLoaded := False;

finalization

LibXmlShutDown;

end.
