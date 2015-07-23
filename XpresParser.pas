{Unidad con funciones básicas del Analizador sintáctico(como el analizador de
expresiones aritméticas).
Se define la clase base "TCompilerBase", de donde debe derivarse el objeto
compilador.
El diseño de esta unidad es un poco especial.
"TCompilerBase", usa variables estáticas definidas en esta unidad, para facilitar el
acceso a estas variables, desde fuera de la unidad (sin necesidad de referirse al
objeto).
De ello se deduce que solo se soporta crear una instacia de "TCompilerBase" a la
vez.
"TCompilerBase", se definió como una clase (porque en realidad pudo haberse creado
como un conjunto de métodos estáticos), para facilitar el poder sobreescribir
algunas rutinas y poder personalizar mejor a la unidad.

 Aquí también se incluye el archivo en donde se implementará un intérprete/compilador.
 Las variables importantes de este módulo son:

 xLex -> es el analizador léxico y resaltador de sintaxis.
 PErr -> es el objeto que administra los errores.
 vars[]  -> almacena a las variables declaradas
 types[] -> almacena a los tipos declarados
 funcs[] -> almacena a las funciones declaradas
 cons[]  -> almacena a las constantes declaradas
}
unit XPresParser;
interface
uses
  Classes, SysUtils, fgl, Forms, LCLType, Dialogs, lclProc,
  SynEditHighlighter, SynFacilHighlighter, SynFacilBasic,
  XpresBas, FormOut;

type

//Categoría de Operando
CatOperan = (
  coConst,     //mono-operando constante
  coVariab,  //variable
  coExpres     //expresión
);

//categorías básicas de tipo de datos
TCatType=(
  t_integer,  //números enteros
  t_uinteger, //enteros sin signo
  t_float,    //es de coma flotante
  t_string,   //cadena de caracteres
  t_boolean,  //booleano
  t_enum      //enumerado
);

//tipo de identificador
TIdentifType = (idtNone, idtVar, idtFunc, idtCons);

TType = class;
TOperator = class;

//registro para almacenar información de las variables
Tvar = record
  nom : string;   //nombre de la variable
  typ : Ttype;    //tipo de la variable
  amb : string;   //ámbito o alcance de la variable
  //direción física. Usado para implementar un compilador
  adrr: integer;
  //Campos usados para implementar el intérprete sin máquina virtual
  //valores de la variable.
  valInt  : Int64;    //valor en caso de que sea un entero
  valUInt : Int64;    //valor en caso de que sea un entero sin signo
  valFloat: extended; //Valor en caso de que sea un flotante
  valBool  : Boolean;  //valor  en caso de que sea un booleano
  valStr  : string;    //valor  en caso de que sea una cadena
end;

{ TOperand }
//Operando
TOperand = object
private
//    cons: Tvar;        //valor en caso de que sea una constante
public
  catTyp: TCatType;  //Categoría de Tipo de dato { TODO : No debría ser nevesario }
  typ   : TType;     //Referencia al tipo de dato
  size  : integer;   //Tamaño del operando en bytes
  catOp : CatOperan; //Categoría de operando
  txt  : string;    //Texto del operando o expresión, tal como aparece en la fuente
  ifun : integer;   //índice a funciones, en caso de que sea función
  ivar : integer;   //índice a variables, en caso de que sea variable
  function VarName: string; inline; //nombre de la variable, cuando sea de categ. coVariab
  procedure Load; inline;  //carga el operador en registro o pila
  procedure Push; inline;  //pone el operador en la pila
  procedure Pop; inline;   //saca el operador en la pila
  function FindOperator(const oper: string): TOperator; //devuelve el objeto operador
  function GetOperator: Toperator;
public
  //Campos para alamcenar los valores, en caso de que el operando sea una constante
  //Debe tener tantas variables como tipos básicos de variable haya en "TCatType"
  valInt  : Int64;    //valor en caso de que sea un entero
  valUInt : Int64;    //valor en caso de que sea un entero sin signo
  valFloat: extended; //Valor en caso de que sea un flotante
  valBool  : Boolean;  //valor  en caso de que sea un booleano
  valStr  : string;    //valor  en caso de que sea una cadena
//Métodos para facilitar la implementación del intérprete
public
  function expres: string;  //devuelve una cadena que expresa al operando
  //Permite para obtener valores del operando, independeintemente del tipo de operando.
  function GetValBool: boolean;
  function GetValInt: int64;
  function GetValFloat: extended;
  function GetValStr: string;
end;
TProcLoadOperand = procedure(const Op: TOperand);

TProcDefineVar = procedure(const varName, varInitVal: string);
TProcExecOperat = procedure;
TProcExecFunction = procedure;

//"Tipos de datos"

//Tipo operación
TxOperation = class
  OperatType : TType;   //tipo de Operando sobre el cual se aplica la operación.
  proc       : TProcExecOperat;  //Procesamiento de la operación
end;

TOperations = specialize TFPGObjectList<TxOperation>; //lista de bloques

//Operador
{ TOperator }

TOperator = class
  txt: string;    //cadena del operador '+', '-', '++', ...
  jer: byte;      //precedencia
  nom: string;    //nombre de la operación (suma, resta)
  idx: integer;   //ubicación dentro de un arreglo
  Operations: TOperations;  //operaciones soportadas. Debería haber tantos como
                            //Num. Operadores * Num.Tipos compatibles.
  function CreateOperation(OperadType: Ttype; proc: TProcExecOperat): TxOperation;  //Crea operación
  function FindOperation(typ0: Ttype): TxOperation;  //Busca una operación para este operador
  constructor Create;
  destructor Destroy; override;
end;

TOperators = specialize TFPGObjectList<TOperator>; //lista de bloques

{ TType }
//"Tipos de datos"
TType = class
  name : string;      //nombre del tipo ("int8", "int16", ...)
  cat  : TCatType;    //categoría del tipo (numérico, cadena, etc)
  size : smallint;    //tamaño en bytes del tipo
  idx  : smallint;    //ubicación dentro de la matriz de tipos
  amb  : TFaSynBlock; //ámbito de validez del tipo
  OnDefine: TProcDefineVar;   {Evento. Es llamado cada vez que se encuentra la
                               declaración de una variable (de este tipo). }
  OnLoad  : TProcLoadOperand; {Evento. Es llamado cuando se pide cargar un operando
                               (de este tipo) en registro o pila. Por lo general, se
                               hace como parte de la evaluación de una expresión. }
  OnPush  : TProcLoadOperand; {Evento. Es llamado cuando se pide cargar un operando
                               (de este tipo) en la pila. }
  OnPop   : TProcLoadOperand; {Evento. Es llamado cuando se pide cargar un operando
                               (de este tipo) en la pila. }
  codLoad: string;   //código de carga de operando. Se usa si "onLoad" es NIL.
  Operators: TOperators;      //operadores soportados
//  procedure DefineLoadOperand(codLoad0: string);  //Define carga de un operando
  function CreateOperator(txt0: string; jer0: byte; name0: string): TOperator; //Crea operador
  function FindOperator(const Opr: string): TOperator;  //indica si el operador está definido
  constructor Create;
  destructor Destroy; override;
end;

//Lista de tipos
TTypes = specialize TFPGObjectList<TType>; //lista de bloques

TFindFuncResult = (TFF_NONE, TFF_PARTIAL, TFF_FULL);

//registro para almacenar información de las funciones
Tfunc = record
  name: string;   //nombre de la función
  typ : Ttype;    //tipo que devuelve
  pars: array of Ttype;  //parámetros de entrada
  amb : string;   //ámbito o alcance de la función
  //direción física. Usado para implementar un compilador
  adrr: integer;  //dirección física
  //Campos usados para implementar el intérprete sin máquina virtual
  proc: TProcExecFunction;  //referencia a la función que implementa
  posF: TPoint;    //posición donde empieza la función en el código
end;

{ TCompiler }

{Clase base para crear al objeto compilador}
TCompilerBase = class
protected  //Eventos del compilador
  {Notar que estos eventos no se definen para usar métofdos de objetos, sino que
  por comodidad para impementar el intérprete (y espero que por velocidad), usan
  simples procedimientos aislados}
  OnExprStart: procedure(const exprLevel: integer);     {Se genera al iniciar la
                                                     evaluación de una expresión.}
  OnExprEnd  : procedure(const exprLevel: integer; isParam: boolean);  {Se genera
                                             el terminar de evaluar una expresión}
  ExprLevel: Integer;  //Nivel de anidamiento de la rutina de evaluación de expresiones
  procedure ClearTypes;
  function CreateType(nom0: string; cat0: TCatType; siz0: smallint): TType;
  function CreateSysFunction(funName: string; typ: ttype; proc: TProcExecFunction
    ): integer;
  procedure CreateParam(ifun: integer; name: string; typ: ttype);
  function CapturaDelim: boolean;
  procedure CompileVarDeclar;
  procedure CompileCurBlock; virtual;
  procedure ClearVars;
  procedure ClearAllConst;
  procedure ClearAllFuncs;
  procedure ClearAllVars;
  procedure ClearFuncs;
  function CategName(cat: TCatType): string;
  procedure TipDefecBoolean(var Op: TOperand; tokcad: string);
  procedure TipDefecNumber(var Op: TOperand; toknum: string);
  procedure TipDefecString(var Op: TOperand; tokcad: string); virtual;
  function FindDuplicFunction: boolean;
private
  procedure CaptureParams;
  procedure ClearParamsFunc(ifun: integer);
  procedure CreateFunction(funName, varType: string);
  function CreateFunction(funName: string; typ: ttype; proc: TProcExecFunction
    ): integer;
  procedure CreateVariable(varName, varType: string);
  function EOBlock: boolean;
  function EOExpres: boolean;
  procedure Evaluar(var Op1: TOperand; opr: TOperator; var Op2: TOperand);
  function FindCons(const conName: string; out idx: integer): boolean;
  function FindFunc(const funName: string; out idx: integer): boolean;
  function FindFuncWithParams0(const funName: string; var idx: integer;
    idx0: integer=1): TFindFuncResult;
  function FindPredefName(name: string): TIdentifType;
  function FindVar(const varName: string; out idx: integer): boolean;
  procedure GetBoolExpression;
  procedure GetExpression(const prec: Integer; isParam: boolean=false);
  function GetExpressionCore(const prec: Integer): TOperand;
  function GetOperand: TOperand;
  function GetOperandP(pre: integer): TOperand;
  function SameParamsFunctions(iFun1, iFun2: integer): boolean;
public
  PErr  : TPError;     //Objeto de Error
  xLex  : TSynFacilSyn; //resaltador - lexer
  //variables públicas del compilador
  ejecProg: boolean;   //Indica que se está ejecutando un programa o compilando
  DetEjec: boolean;   //para detener la ejecución (en intérpretes)
  function HayError: boolean;
  procedure GenError(msg: string);
  function ArcError: string;
  function nLinError: integer;
  function nColError: integer;
  procedure ShowError;
public
  constructor Create; virtual;
  destructor Destroy; override;
end;

var
  {Variables globales. Realmente deberían ser campos de TCompilerBase. Se ponen aquí,
   para que puedan ser accedidas fácilmente desde el archivo "interprte.pas"}
  res   : TOperand;    //resultado de la evaluación de la última expresión.

  vars  : array of Tvar;  //lista de variables
  funcs : array of Tfunc; //lista de funciones
  cons  : array of Tvar;  //lista de constantes
  nIntVar : integer;    //número de variables internas
  nIntFun : integer;    //número de funciones internas
  nIntCon : integer;    //número de constantes internas

  cIn    : TContexts;   //entrada de datos
  p1, p2 : TOperand;    //Pasa los operandos de la operación actual
  //referencias obligatorias
  tkEol     : TSynHighlighterAttributes;
  tkIdentif : TSynHighlighterAttributes;
  tkKeyword : TSynHighlighterAttributes;
  tkNumber  : TSynHighlighterAttributes;
  tkString  : TSynHighlighterAttributes;
  tkOperator: TSynHighlighterAttributes;
  tkBoolean : TSynHighlighterAttributes;
  tkSysFunct: TSynHighlighterAttributes;
  //referencias adicionales
  tkExpDelim: TSynHighlighterAttributes;
  tkBlkDelim: TSynHighlighterAttributes;
  tkType    : TSynHighlighterAttributes;
  tkStruct  : TSynHighlighterAttributes;
  tkOthers  : TSynHighlighterAttributes;

implementation

uses Graphics;

var
  types  : TTypes;      //lista de tipos
//    oper: string;      //indica el operador actual
  //tipos de tokens

var  //variables privadas del compilador

  nullOper : TOperator; //Operador nulo. Usado como valor cero.



  {Parte del código de XpresParser, que se espera que se mantenga fija aún con
diversas implementaciones.
En principio no se debería incluir código que use SkipWhites() o SkipWhitesEOL(),
porque usar una u otra función excluiría a lso casos en que se requiera a la otra
función}
//////////////// implementación de métodos  //////////////////
{ TOperator }

function TOperator.CreateOperation(OperadType: Ttype; proc: TProcExecOperat): TxOperation;
var
  r: TxOperation;
begin
  //agrega
  r := TxOperation.Create;
  r.OperatType:=OperadType;
//  r.CodForConst:=codCons;
//  r.CodForVar:=codVar;
//  r.CodForExpr:=codExp;
  r.proc:=proc;
  //agrega
  operations.Add(r);
  Result := r;
end;
function TOperator.FindOperation(typ0: Ttype): TxOperation;
{Busca, si encuentra definida, alguna operación, de este operador con el tipo indicado.
Si no lo encuentra devuelve NIL}
var
  r: TxOperation;
begin
  Result := nil;
  for r in Operations do begin
    if r.OperatType = typ0 then begin
      exit(r);
    end;
  end;
end;
constructor TOperator.Create;
begin
  Operations := TOperations.Create(true);
end;
destructor TOperator.Destroy;
begin
  Operations.Free;
  inherited Destroy;
end;

{ TType }

function TType.CreateOperator(txt0: string; jer0: byte; name0: string): TOperator;
{Permite crear un nuevo ooperador soportado por este tipo de datos. Si hubo error,
devuelve NIL. En caso normal devuelve una referencia al operador creado}
var
  r: TOperator;  //operador
begin
  //verifica nombre
  if FindOperator(txt0)<>nullOper then begin
    Result := nil;  //indica que hubo error
    exit;
  end;
  //inicia
  r := TOperator.Create;
  r.txt:=txt0;
  r.jer:=jer0;
  r.nom:=name0;
  r.idx:=Operators.Count;
  //agrega
  Operators.Add(r);
  Result := r;
end;
function TType.FindOperator(const Opr: string): TOperator;
//Recibe la cadena de un operador y devuelve una referencia a un objeto Toperator, del
//tipo. Si no está definido el operador para este tipo, devuelve nullOper.
var
  i: Integer;
begin
  Result := nullOper;   //valor por defecto
  for i:=0 to Operators.Count-1 do begin
    if Operators[i].txt = upCase(Opr) then begin
      exit(Operators[i]); //está definido
    end;
  end;
  //no encontró
  Result.txt := Opr;    //para que sepa el operador leído
end;
constructor TType.Create;
begin
  Operators := TOperators.Create(true);  //crea contenedor de Contextos, con control de objetos.
end;
destructor TType.Destroy;
begin
  Operators.Free;
  inherited Destroy;
end;

{TCompilerBase}

function TCompilerBase.HayError: boolean;
begin
  Result := PErr.HayError;
end;
procedure TCompilerBase.GenError(msg: string);
{Función de acceso rápido para Perr.GenError(). Pasa como posición a la posición
del contexto actual.
Se declara como función para poder usarla directamente en el exit() de una función}
begin
  if cIn = nil then
    Perr.GenError(msg,'',1)
  else
    Perr.GenError(msg, cIn.curCon);
end;
function TCompilerBase.ArcError: string;
begin
  Result:= Perr.ArcError;
end;
function TCompilerBase.nLinError: integer;
begin
  Result := Perr.nLinError;
end;
function TCompilerBase.nColError: integer;
begin
  Result := Perr.nColError;
end;
procedure TCompilerBase.ShowError;
begin
  Application.MessageBox(PChar(Perr.TxtErrorRC),
                         PChar(Perr.NombPrograma), MB_ICONEXCLAMATION);
//  Perr.Show;
end;

function TCompilerBase.FindVar(const varName:string; out idx: integer): boolean;
//Busca el nombre dado para ver si se trata de una variable definida
//Si encuentra devuelve TRUE y actualiza el índice.
var
  tmp: String;
  i: Integer;
begin
  Result := false;
  tmp := upCase(varName);
  for i:=0 to high(vars) do begin
    if Upcase(vars[i].nom)=tmp then begin
      idx := i;
      exit(true);
    end;
  end;
end;
function TCompilerBase.FindFunc(const funName:string; out idx: integer): boolean;
//Busca el nombre dado para ver si se trata de una función definida
//Si encuentra devuelve TRUE y actualiza el índice.
var
  tmp: String;
  i: Integer;
begin
  Result := false;
  tmp := upCase(funName);
  for i:=0 to high(funcs) do begin
    if Upcase(funcs[i].name)=tmp then begin
      idx := i;
      exit(true);
    end;
  end;
end;
function TCompilerBase.FindCons(const conName:string; out idx: integer): boolean;
//Busca el nombre dado para ver si se trata de una constante definida
//Si encuentra devuelve TRUE y actualiza el índice.
var
  tmp: String;
  i: Integer;
begin
  Result := false;
  tmp := upCase(conName);
  for i:=0 to high(cons) do begin
    if Upcase(cons[i].nom)=tmp then begin
      idx := i;
      exit(true);
    end;
  end;
end;
function TCompilerBase.FindPredefName(name: string): TIdentifType;
//Busca un identificador e indica si ya existe el nombre, sea como variable,
//función o constante.
var i: integer;
begin
  //busca como variable
  if FindVar(name,i) then begin
     exit(idtVar);
  end;
  //busca como función
  if FindFunc(name,i) then begin
     exit(idtFunc);
  end;
  //busca como constante
  if FindCons(name,i) then begin
     exit(idtCons);
  end;
  //no lo encuentra
  exit(idtNone);
end;

//Manejo de tipos
function TCompilerBase.CreateType(nom0: string; cat0: TCatType; siz0: smallint): TType;
//Crea una nueva definición de tipo en el compilador. Devuelve referencia al tipo recien creado
var r: TType;
  i: Integer;
begin
  //verifica nombre
  for i:=0 to types.Count-1 do begin
    if types[i].name = nom0 then begin
      GenError('Identificador de tipo duplicado.');
      exit;
    end;
  end;
  //configura nuevo tipo
  r := TType.Create;
  r.name:=nom0;
  r.cat:=cat0;
  r.size:=siz0;
  r.idx:=types.Count;  //toma ubicación
//  r.amb:=;  //debe leer el bloque actual
  //agrega
  types.Add(r);
  Result:=r;   //devuelve índice al tipo
end;
procedure TCompilerBase.ClearTypes;  //Limpia los tipos
begin
  types.Clear;
end;
procedure TCompilerBase.ClearVars;
//Limpia todas las variables creadas por el usuario.
begin
  setlength(vars, nIntVar);  //deja las del sistema
end;
procedure TCompilerBase.ClearAllVars;
//Elimina todas las variables, incluyendo las predefinidas.
begin
  nIntVar := 0;
  setlength(vars,0);
end;
procedure TCompilerBase.ClearFuncs;
//Limpia todas las funciones creadas por el usuario.
begin
  setlength(funcs,nIntFun);  //deja las del sistema
end;
procedure TCompilerBase.ClearAllFuncs;
//Elimina todas las funciones, incluyendo las predefinidas.
begin
  nIntFun := 0;
  setlength(funcs,0);
end;
procedure TCompilerBase.ClearAllConst;
//Elimina todas las funciones, incluyendo las predefinidas.
begin
  nIntCon := 0;
  setlength(cons,0);
end;

function TCompilerBase.CreateFunction(funName: string; typ: ttype; proc: TProcExecFunction): integer;
//Crea una nueva función y devuelve un índice a la función.
var
  r : Tfunc;
  i, n: Integer;
begin
  //verifica si existe como variable
  if FindVar(funName, i) then begin
    GenError('Identificador duplicado: "' + funName + '".');
    exit;
  end;
  //verifica si existe como constante
  if FindCons(funName, i)then begin
    GenError('Identificador duplicado: "' + funName + '".');
    exit;
  end;
  //puede existir como función, no importa (sobrecarga)
  //registra la función en la tabla
  r.name:= funName;
  r.typ := typ;
  r.proc:= proc;
  setlength(r.pars,0);  //inicia arreglo
  //agrega
  n := high(funcs)+1;
  setlength(funcs, n+1);
  funcs[n] := r;
  Result := n;
end;
function TCompilerBase.CreateSysFunction(funName: string; typ: ttype; proc: TProcExecFunction): integer;
//Crea una función del sistema o interna. Estas funciones estan siempre disponibles.
//Las funciones internas deben crearse todas al inicio.
begin
  Result := CreateFunction(funName, typ, proc);
  Inc(nIntFun);  //leva la cuenta
end;
procedure TCompilerBase.CreateFunction(funName, varType: string);
//Define una nueva función en memoria.
var t: ttype;
  hay: Boolean;
begin
  //Verifica el tipo
  hay := false;
  for t in types do begin
    if t.name=varType then begin
       hay:=true; break;
    end;
  end;
  if not hay then begin
    GenError('Tipo "' + varType + '" no definido.');
    exit;
  end;
  CreateFunction(funName, t, nil);
  //Ya encontró tipo, llama a evento
//  if t.OnDefine<>nil then t.OnDefine(funName, '');
end;
procedure TCompilerBase.ClearParamsFunc(ifun: integer);  inline;
//Elimina los parámetros de una función
begin
  setlength(funcs[ifun].pars,0);
end;
procedure TCompilerBase.CreateParam(ifun: integer; name: string; typ: ttype);
//Crea un parámetro para una función
var
  n: Integer;
begin
  //agrega
  n := high(funcs[ifun].pars)+1;
  setlength(funcs[ifun].pars, n+1);
  funcs[ifun].pars[n] := typ;  //agrega referencia
end;
function TCompilerBase.SameParamsFunctions(iFun1, iFun2: integer): boolean;
//Compara los parámetros de dos funciones. Si tienen el mismo número de
//parámetros y el mismo tipo, devuelve TRUE.
var
  i: Integer;
begin
  Result:=true;  //se asume que son iguales
  if High(funcs[iFun1].pars) <> High(funcs[iFun2].pars) then
    exit(false);   //distinto número de parámetros
  //hay igual número de parámetros, verifica
  for i := 0 to High(funcs[iFun1].pars) do begin
    if funcs[iFun1].pars[i] <> funcs[iFun2].pars[i] then begin
      exit(false);
    end;
  end;
  //si llegó hasta aquí, hay coincidencia, sale con TRUE
end;
function TCompilerBase.FindFuncWithParams0(const funName: string; var idx: integer;
  idx0 : integer = 1): TFindFuncResult;
{Busca una función que coincida con el nombre "funName" y con los parámetros de funcs[0]
El resultado puede ser:
 TFF_NONE   -> No se encuentra.
 TFF_PARTIAL-> Se encuentra solo el nombre.
 TFF_FULL   -> Se encuentra y coninciden sus parámetros, actualiza "idx".
"idx0", es el índice inicial desde donde debe buscar. Permite acelerar las búsquedas, cuando
ya se ha explorado antes.
}
var
  tmp: String;
  params : string;   //parámetros de la función
  i: Integer;
  hayFunc: Boolean;
begin
  Result := TFF_NONE;   //por defecto
  hayFunc := false;
  tmp := UpCase(funName);
  for i:=idx0 to high(funcs) do begin  //no debe empezar en 0, porque allí está func[0]
    if Upcase(funcs[i].name)= tmp then begin
      //coincidencia, compara
      hayFunc := true;  //para indicar que encontró el nombre
      if SameParamsFunctions(i,0) then begin
        idx := i;    //devuelve ubicación
        Result := TFF_FULL; //encontró
        exit;
      end;
    end;
  end;
  //si llego hasta aquí es porque no encontró coincidencia
  if hayFunc then begin
    //Encontró al menos el nombre de la función, pero no coincide en los parámetros
    Result := TFF_PARTIAL;
    {Construye la lista de parámetros de las funciones con el mismo nombre. Solo
    hacemos esta tarea pesada aquí, porque  sabemos que se detendrá la compilación}
    params := '';   //aquí almacenará la lista
{    for i:=idx0 to high(funcs) do begin  //no debe empezar 1n 0, porque allí está func[0]
      if Upcase(funcs[i].name)= tmp then begin
        for j:=0 to high(funcs[i].pars) do begin
          params += funcs[i].pars[j].name + ',';
        end;
        params += LineEnding;
      end;
    end;}
  end;
end;
function TCompilerBase.FindDuplicFunction: boolean;
//Verifica si la última función agregada, está duplicada con alguna de las
//funciones existentes. Permite la sobrecarga. Si encuentra la misma
//función definida 2 o más veces, genera error y devuelve TRUE.
//DEbe llamarse siempre, después de definir una función nueva.
var
  ufun : String;
  i,j,n: Integer;
  tmp: String;
begin
  Result := false;
  n := high(funcs);  //última función
  ufun := funcs[n].name;
  //busca sobrecargadas en las funciones anteriores
  for i:=0 to n-1 do begin
    if funcs[i].name = ufun then begin
      //hay una sobrecargada, verifica tipos de parámetros
      if not SameParamsFunctions(i,n) then break;
      //Tiene igual cantidad de parámetros y del mismo tipo. Genera Error
      tmp := '';
      for j := 0 to High(funcs[i].pars) do begin
        tmp += funcs[n].pars[j].name+', ';
      end;
      if length(tmp)>0 then tmp := copy(tmp,1,length(tmp)-2); //quita coma final
      GenError('Función '+ufun+'( '+tmp+' ) duplicada.');
      exit(true);
    end;
  end;
end;
function TCompilerBase.CategName(cat: TCatType): string;
begin
   case cat of
   t_integer: Result := 'Numérico';
   t_uinteger: Result := 'Numérico sin signo';
   t_float: Result := 'Flotante';
   t_string: Result := 'Cadena';
   t_boolean: Result := 'Booleano';
   t_enum: Result := 'Enumerado';
   else Result := 'Desconocido';
   end;
end;
function TCompilerBase.EOBlock: boolean; inline;
//Indica si se ha llegado el final de un bloque
begin
  Result := cIn.tokType = tkBlkDelim;
end;
function TCompilerBase.EOExpres: boolean; inline;
//Indica si se ha llegado al final de una expresión
begin
  Result := cIn.tokType = tkExpDelim;
end;
{ Rutinas del compilador }
function TCompilerBase.CapturaDelim: boolean;
//Verifica si sigue un delimitador de expresión. Si encuentra devuelve false.
begin
  cIn.SkipWhites;
  if cIn.tokType=tkExpDelim then begin //encontró
    cIn.Next;   //pasa al siguiente
    exit(true);
  end else if cIn.tokL = 'end' then begin   //es un error
    //detect apero no lo toma
    exit(true);  //sale con error
  end else begin   //es un error
    GenError('Se esperaba ";"');
    exit(false);  //sale con error
  end;

end;
procedure TCompilerBase.TipDefecNumber(var Op: TOperand; toknum: string);
//Devuelve el tipo de número entero o fltante más sencillo que le corresponde a un token
//que representa a una constante numérica.
//Su forma de trabajo es buscar el tipo numérico más pequeño que permita alojar a la
//constante numérica indicada.

var
  n: int64;   //para almacenar a los enteros
  f: extended;  //para almacenar a reales
  i: Integer;
  menor: Integer;
  imen: integer;
begin
  if pos('.',toknum) <> 0 then begin  //es flotante
    Op.catTyp := t_float;   //es flotante
    try
      f := StrToFloat(toknum);  //carga con la mayor precisión posible
    except
      Op.typ := nil;
      GenError('Número decimal no válido.');
      exit;
    end;
    //busca el tipo numérico más pequeño que pueda albergar a este número
    Op.size := 4;   //se asume que con 4 bytes bastará
    {Aquí se puede decidir el tamaño de acuerdo a la cantidad de decimales indicados}

    Op.valFloat := f;  //debe devolver un extended
    menor := 1000;
    for i:=0 to types.Count-1 do begin
      { TODO : Se debería tener una lista adicional TFloatTypes, para acelerar la
      búsqueda}
      if (types[i].cat = t_float) and (types[i].size>=Op.size) then begin
        //guarda el menor
        if types[i].size < menor then  begin
           imen := i;   //guarda referencia
           menor := types[i].size;
        end;
      end;
    end;
    if menor = 1000 then  //no hubo tipo
      Op.typ := nil
    else  //encontró
      Op.typ:=types[imen];

  end else begin     //es entero
    Op.catTyp := t_integer;   //es entero
    //verificación de longitud de entero
    if length(toknum)>=19 then begin  //solo aquí puede haber problemas
      if toknum[1] = '-' then begin  //es negativo
        if length(toknum)>20 then begin
          GenError('Número muy grande. No se puede procesar. ');
          exit
        end else if (length(toknum) = 20) and  (toknum > '-9223372036854775808') then begin
          GenError('Número muy grande. No se puede procesar. ');
          exit
        end;
      end else begin  //es positivo
        if length(toknum)>19 then begin
          GenError('Número muy grande. No se puede procesar. ');
          exit
        end else if (length(toknum) = 19) and  (toknum > '9223372036854775807') then begin
          GenError('Número muy grande. No se puede procesar. ');
          exit
        end;
      end;
    end;
    //conversión. aquí ya no debe haber posibilidad de error
    n := StrToInt64(toknum);
    if (n>= -128) and  (n<=127) then
        Op.size := 1
    else if (n>= -32768) and (n<=32767) then
        Op.size := 2
    else if (n>= -2147483648) and (n<=2147483647) then
        Op.size := 4
    else if (n>= -9223372036854775808) and (n<=9223372036854775807) then
        Op.size := 8;
    Op.valInt := n;   //copia valor de constante entera
    //busca si hay tipo numérico que soporte esta constante
{      Op.typ:=nil;
    for i:=0 to types.Count-1 do begin
      { TODO : Se debería tener una lista adicional  TIntegerTypes, para acelerar la
      búsqueda}
      if (types[i].cat = t_integer) and (types[i].size=Op.size) then
        Op.typ:=types[i];  //encontró
    end;}
    //busca el tipo numérico más pequeño que pueda albergar a este número
    menor := 1000;
    for i:=0 to types.Count-1 do begin
      { TODO : Se debería tener una lista adicional  TIntegerTypes, para acelerar la
      búsqueda}
      if (types[i].cat = t_integer) and (types[i].size>=Op.size) then begin
        //guarda el menor
        if types[i].size < menor then  begin
           imen := i;   //guarda referencia
           menor := types[i].size;
        end;
      end;
    end;
    if menor = 1000 then  //no hubo tipo
      Op.typ := nil
    else  //encontró
      Op.typ:=types[imen];
  end;
end;
procedure TCompilerBase.TipDefecString(var Op: TOperand; tokcad: string);
//Devuelve el tipo de cadena encontrado en un token
var
  i: Integer;
  x: TType;
begin
  Op.catTyp := t_string;   //es cadena
  Op.size:=length(tokcad);
  //toma el texto
  Op.valStr := copy(cIn.tok,2, length(cIn.tok)-2);   //quita comillas
  //////////// Verifica si hay tipos string definidos ////////////
  Op.typ:=nil;
  //Busca primero tipo string (longitud variable)
  for i:=0 to types.Count-1 do begin
    { TODO : Se debería tener una lista adicional  TStringTypes, para acelerar la
    búsqueda}
    x := types[i];
    if (types[i].cat = t_string) and (types[i].size=-1) then begin  //busca un char
      Op.typ:=types[i];  //encontró
      break;
    end;
  end;
  if Op.typ=nil then begin
    //no hubo "string", busca al menos "char", para generar ARRAY OF char
    for i:=0 to types.Count-1 do begin
      { TODO : Se debería tener una lista adicional  TStringTypes, para acelerar la
      búsqueda}
      if (types[i].cat = t_string) and (types[i].size=1) then begin  //busca un char
        Op.typ:=types[i];  //encontró
        break;
      end;
    end;
  end;
end;
procedure TCompilerBase.TipDefecBoolean(var Op: TOperand; tokcad: string);
//Devuelve el tipo de cadena encontrado en un token
var
  i: Integer;
begin
  Op.catTyp := t_boolean;   //es flotante
  Op.size:=1;   //se usará un byte
  //toma valor constante
  Op.valBool:= (tokcad[1] in ['t','T']);
  //verifica si hay tipo boolean definido
  Op.typ:=nil;
  for i:=0 to types.Count-1 do begin
    { TODO : Se debería tener una lista adicional  TBooleanTypes, para acelerar la
    búsqueda}
    if (types[i].cat = t_boolean) then begin  //basta con que haya uno
      Op.typ:=types[i];  //encontró
      break;
    end;
  end;
end;
procedure TCompilerBase.CaptureParams;
//Lee los parámetros de una función en la función interna funcs[0]
begin
  cIn.SkipWhites;
  ClearParamsFunc(0);   //inicia parámetros
  if EOBlock or EOExpres then begin
    //no tiene parámetros
  end else begin
    //Debe haber parámetros
    if cIn.tok<>'(' then begin
      GenError('Se esperaba "("'); exit;
    end;
    cin.Next;
    repeat
      GetExpression(0, true);  //captura parámetro
      if perr.HayError then exit;   //aborta
      //guarda tipo de parámetro
      CreateParam(0,'', res.typ);
      if cIn.tok = ',' then begin
        cIn.Next;   //toma separador
        cIn.SkipWhites;
      end else begin
        //no sigue separador de parámetros,
        //debe terminar la lista de parámetros
        //¿Verificar EOBlock or EOExpres ?
        break;
      end;
    until false;
    //busca paréntesis final
    if cIn.tok<>')' then begin
      GenError('Se esperaba ")"'); exit;
    end;
    cin.Next;
  end;
end;
function TCompilerBase.GetOperand: TOperand;
{Parte de la funcion GAEE que genera codigo para leer un operando.
Debe devolver el tipo del operando y también el valor (obligatorio para el caso
de intérpretes y opcional para compiladores)}
var
  i: Integer;
  hayFunc: Boolean;
  ivar: Integer;
  ifun: Integer;
  tmp: String;
begin
  PErr.Clear;
  cIn.SkipWhites;
  if cIn.tokType = tkNumber then begin  //constantes numéricas
    Result.catOp:=coConst;       //constante es Mono Operando
    Result.txt:= cIn.tok;     //toma el texto
    TipDefecNumber(Result, cIn.tok); //encuentra tipo de número, tamaño y valor
    if pErr.HayError then exit;  //verifica
    if Result.typ = nil then begin
        GenError('No hay tipo definido para albergar a esta constante numérica');
        exit;
      end;
    cIn.Next;    //Pasa al siguiente
  end else if cIn.tokType = tkIdentif then begin  //puede ser variable, constante, función
    if FindVar(cIn.tok, ivar) then begin
      //es una variable
      Result.ivar:=ivar;   //guarda referencia a la variable
      Result.catOp:=coVariab;    //variable
      Result.catTyp:= vars[ivar].typ.cat;  //categoría
      Result.typ:=vars[ivar].typ;
      Result.txt:= cIn.tok;     //toma el texto
      cIn.Next;    //Pasa al siguiente
    end else if FindFunc(cIn.tok, ifun) then begin  //no es variable, debe ser función
      tmp := cIn.tok;  //guarda nombre de función
      cIn.Next;    //Toma identificador
      CaptureParams;  //primero lee parámetros
      if HayError then exit;
      //busca como función
      case FindFuncWithParams0(tmp, i, ifun) of  //busca desde ifun
      //TFF_NONE:      //No debería pasar esto
      TFF_PARTIAL:   //encontró la función, pero no coincidió con los parámetros
         GenError('Error en tipo de parámetros de '+ tmp +'()');
      TFF_FULL:     //encontró completamente
        begin   //encontró
          Result.ifun:=i;      //guarda referencia a la función
          Result.catOp :=coExpres; //expresión
          Result.txt:= cIn.tok;    //toma el texto
    //      Result.catTyp:= funcs[i].typ.cat;  //no debería ser necesario
          Result.typ:=funcs[i].typ;
          funcs[i].proc;  //llama al código de la función
          exit;
        end;
      end;
    end else begin
      GenError('Identificador desconocido: "' + cIn.tok + '"');
      exit;
    end;
  end else if cIn.tokType = tkSysFunct then begin  //es función de sistema
    //Estas funciones debem crearse al iniciar el compilador y están siempre disponibles.
    tmp := cIn.tok;  //guarda nombre de función
    cIn.Next;    //Toma identificador
    CaptureParams;  //primero lee parámetros en func[0]
    //buscamos una declaración que coincida.
    case FindFuncWithParams0(tmp, i) of
    TFF_NONE:      //no encontró ni la función
       GenError('Función no implementada: "' + tmp + '"');
    TFF_PARTIAL:   //encontró la función, pero no coincidió con los parámetros
       GenError('Error en tipo de parámetros de '+ tmp +'()');
    TFF_FULL:     //encontró completamente
      begin   //encontró
        Result.ifun:=i;      //guarda referencia a la función
        Result.catOp :=coExpres; //expresión
        Result.txt:= cIn.tok;    //toma el texto
  //      Result.catTyp:= funcs[i].typ.cat;  //no debería ser necesario
        Result.typ:=funcs[i].typ;
        funcs[i].proc;  //llama al código de la función
        exit;
      end;
    end;
  end else if cIn.tokType = tkBoolean then begin  //true o false
    Result.catOp:=coConst;       //constante es Mono Operando
    Result.txt:= cIn.tok;     //toma el texto
    TipDefecBoolean(Result, cIn.tok); //encuentra tipo de número, tamaño y valor
    if pErr.HayError then exit;  //verifica
    if Result.typ = nil then begin
       GenError('No hay tipo definido para albergar a esta constante booleana');
       exit;
     end;
    cIn.Next;    //Pasa al siguiente
  end else if (cIn.tokType = tkOthers) and (cIn.tok = '(') then begin  //"("
    cIn.Next;
    GetExpression(0);
    Result := res;
    if PErr.HayError then exit;
    If cIn.tok = ')' Then begin
       cIn.Next;  //lo toma
    end Else begin
       GenError('Error en expresión. Se esperaba ")"');
       Exit;       //error
    end;
  end else if (cIn.tokType = tkString) then begin  //constante cadena
    Result.catOp:=coConst;     //constante es Mono Operando
//    Result.txt:= cIn.tok;     //toma el texto
    TipDefecString(Result, cIn.tok); //encuentra tipo de número, tamaño y valor
    if pErr.HayError then exit;  //verifica
    if Result.typ = nil then begin
       GenError('No hay tipo definido para albergar a esta constante cadena');
       exit;
     end;
    cIn.Next;    //Pasa al siguiente
{  end else if (cIn.tokType = tkOperator then begin
   //los únicos símbolos válidos son +,-, que son parte de un número
    }
  end else begin
    //No se reconoce el operador
    GenError('Se esperaba operando');
  end;
end;
procedure TCompilerBase.CreateVariable(varName, varType: string);
//Se debe reservar espacio para las variables indicadas. Los tipos siempre
//aparecen en minúscula.
var t: ttype;
  hay: Boolean;
  n: Integer;
  r : Tvar;
begin
  //Verifica el tipo
  hay := false;
  for t in types do begin
    if t.name=varType then begin
       hay:=true; break;
    end;
  end;
  if not hay then begin
    GenError('Tipo "' + varType + '" no definido.');
    exit;
  end;
  //verifica nombre
  if FindPredefName(varName) <> idtNone then begin
    GenError('Identificador duplicado: "' + varName + '".');
    exit;
  end;
  //registra variable en la tabla
  r.nom:=varName;
  r.typ := t;
  n := high(vars)+1;
  setlength(vars, n+1);
  vars[n] := r;
  //Ya encontró tipo, llama a evento
  if t.OnDefine<>nil then t.OnDefine(varName, '');
end;
procedure TCompilerBase.CompileVarDeclar;
//Compila la declaración de variables.
var
  varType: String;
  varName: String;
  varNames: array of string;  //nombre de variables
  n: Integer;
  tmp: String;
begin
  setlength(varNames,0);  //inicia arreglo
  //procesa variables res,b,c : int;
  repeat
    cIn.SkipWhites;
    //ahora debe haber un identificador de variable
    if cIn.tokType <> tkIdentif then begin
      GenError('Se esperaba identificador de variable.');
      exit;
    end;
    //hay un identificador
    varName := cIn.tok;
    cIn.Next;  //lo toma
    cIn.SkipWhites;
    //sgrega nombre de variable
    n := high(varNames)+1;
    setlength(varNames,n+1);  //hace espacio
    varNames[n] := varName;  //agrega nombre
    if cIn.tok <> ',' then break; //sale
    cIn.Next;  //toma la coma
  until false;
  //usualmente debería seguir ":"
  if cIn.tok = ':' then begin
    //debe venir el tipo de la variable
    cIn.Next;  //lo toma
    cIn.SkipWhites;
    if (cIn.tokType <> tkType) then begin
      GenError('Se esperaba identificador de tipo.');
      exit;
    end;
    varType := cIn.tok;   //lee tipo
    cIn.Next;
    //reserva espacio para las variables
    for tmp in varNames do begin
      CreateVariable(tmp, lowerCase(varType));
      if Perr.HayError then exit;
    end;
  end else begin
    GenError('Se esperaba ":" o ",".');
    exit;
  end;
  if not CapturaDelim then exit;
  cIn.SkipWhites;
end;
procedure TCompilerBase.CompileCurBlock;
//Compila el bloque de código actual hasta encontrar un delimitador de bloque.
begin
  cIn.SkipWhites;
  while not cIn.Eof and not EOBlock do begin
    //se espera una expresión o estructura
    if cIn.tokType = tkStruct then begin  //es una estructura
      if cIn.tokL = 'if' then begin  //condicional
        cIn.Next;  //toma IF
        GetBoolExpression; //evalua expresión
        if PErr.HayError then exit;
        if cIn.tokL<> 'then' then begin
          GenError('Se esperaba "then".');
          exit;
        end;
        cIn.Next;  //toma el THEN
        //cuerpo del if
        CompileCurBlock;  //procesa bloque
//        Result := res;  //toma resultado
        if PErr.HayError then exit;
        while cIn.tokL = 'elsif' do begin
          cIn.Next;  //toma ELSIF
          GetBoolExpression; //evalua expresión
          if PErr.HayError then exit;
          if cIn.tokL<> 'then' then begin
            GenError('Se esperaba "then".');
            exit;
          end;
          cIn.Next;  //toma el THEN
          //cuerpo del if
          CompileCurBlock;  //evalua expresión
//          Result := res;  //toma resultado
          if PErr.HayError then exit;
        end;
        if cIn.tokL = 'else' then begin
          cIn.Next;  //toma ELSE
          CompileCurBlock;  //evalua expresión
//          Result := res;  //toma resultado
          if PErr.HayError then exit;
        end;
        if cIn.tokL<> 'end' then begin
          GenError('Se esperaba "end".');
          exit;
        end;
      end else begin
        GenError('Error de diseño. Estructura no implementada.');
        exit;
      end;
    end else begin  //debe ser una expresión
      GetExpression(0);
      if perr.HayError then exit;   //aborta
    end;
    //se espera delimitador
    if cIn.Eof then break;  //sale por fin de archivo
    //busca delimitador
    cIn.SkipWhites;
    if cIn.tokType=tkExpDelim then begin //encontró delimitador de expresión
      cIn.Next;   //lo toma
      cIn.SkipWhites;  //quita espacios
    end else if cIn.tokType = tkBlkDelim then begin  //hay delimitador de bloque
      exit;  //no lo toma
    end else begin  //hay otra cosa
      exit;  //debe ser un error
    end;
  end;
end;
procedure TCompilerBase.Evaluar(var Op1: TOperand; opr: TOperator; var Op2: TOperand);
{Ejecuta una operación con dos operandos y un operador. "opr" es el operador de Op1.
El resultado debe devolverse en "res". En el caso de intérpretes, importa el
resultado de la Operación.
En el caso de compiladores, lo más importante es el tipo del resultado, pero puede
usarse también "res" para cálculo de expresiones constantes.
}
var
  o: TxOperation;
begin
   debugln(space(ExprLevel)+' Eval('+Op1.txt + ',' + Op2.txt+')');
   PErr.IniError;
   //Busca si hay una operación definida para: <tipo de Op1>-opr-<tipo de Op2>
   o := opr.FindOperation(Op2.typ);
   if o = nil then begin
//      GenError('No se ha definido la operación: (' +
//                    Op1.typ.name + ') '+ opr.txt + ' ('+Op2.typ.name+')');
      GenError('Operación no válida: (' +
                    Op1.typ.name + ') '+ opr.txt + ' ('+Op2.typ.name+')');
      Exit;
    end;
   {Llama al evento asociado con p1 y p2 como operandos. Debe devolver el resultado
   en "res"}
   p1 := Op1; p2 := Op2;  { TODO : Debe optimizarse }
   o.proc;      //Ejecuta la operación
   //El resultado debe estar en "res"
   //Completa campos de "res", si es necesario
//   res.txt := Op1.txt + opr.txt + Op2.txt;   //texto de la expresión
//   res.uop := opr;   //última operación ejecutada
End;
function TCompilerBase.GetOperandP(pre: integer): TOperand;
//Toma un operando realizando hasta encontrar un operador de precedencia igual o menor
//a la indicada
var
  Op1: TOperand;
  Op2: TOperand;
  opr: TOperator;
  pos: TPosCont;
begin
  debugln(space(ExprLevel)+' CogOperando('+IntToStr(pre)+')');
  Op1 :=  GetOperand;  //toma el operador
  if pErr.HayError then exit;
  //verifica si termina la expresion
  pos := cIn.PosAct;    //Guarda por si lo necesita
  cIn.SkipWhites;
  opr := Op1.GetOperator;
  if opr = nil then begin  //no sigue operador
    Result:=Op1;
  end else if opr=nullOper then begin  //hay operador pero, ..
    //no está definido el operador siguente para el Op1, (no se puede comparar las
    //precedencias) asumimos que aquí termina el operando.
    cIn.PosAct := pos;   //antes de coger el operador
    GenError('No está definido el operador: '+ opr.txt + ' para tipo: '+Op1.typ.name);
    exit;
//    Result:=Op1;
  end else begin  //si está definido el operador (opr) para Op1, vemos precedencias
    If opr.jer > pre Then begin  //¿Delimitado por precedencia de operador?
      //es de mayor precedencia, se debe evaluar antes.
      Op2 := GetOperandP(pre);  //toma el siguiente operando (puede ser recursivo)
      if pErr.HayError then exit;
      Evaluar(Op1, opr, Op2);  //devuelve en "res"
      Result:=res;
    End else begin  //la precedencia es menor o igual, debe salir
      cIn.PosAct := pos;   //antes de coger el operador
      Result:=Op1;
    end;
  end;
end;
function TCompilerBase.GetExpressionCore(const prec: Integer): TOperand; //inline;
//Generador de Algoritmos de Evaluacion de expresiones.
//Esta es probablemente la función más importante del compilador
var
  Op1, Op2  : TOperand;   //Operandos
  opr1: TOperator;  //Operadores
begin
  Op1.catTyp:=t_integer;    //asumir opcion por defecto
  Op2.catTyp:=t_integer;   //asumir opcion por defecto
  pErr.Clear;
  //----------------coger primer operando------------------
  Op1 := GetOperand; if pErr.HayError then exit;
  debugln(space(ExprLevel)+' Op1='+Op1.txt);
  //verifica si termina la expresion
  cIn.SkipWhites;
  opr1 := Op1.GetOperator;
  if opr1 = nil then begin  //no sigue operador
    //Expresión de un solo operando. Lo carga por si se necesita
    Op1.Load;   //carga el operador para cumplir
    Op1 := res; //para indicar la categoría del operador
    Result:=Op1;
    exit;  //termina ejecucion
  end;
  //------- sigue un operador ---------
  //verifica si el operador aplica al operando
  if opr1 = nullOper then begin
    GenError('No está definido el operador: '+ opr1.txt + ' para tipo: '+Op1.typ.name);
    exit;
  end;
  //inicia secuencia de lectura: <Operador> <Operando>
  while opr1<>nil do begin
    //¿Delimitada por precedencia?
    If opr1.jer <= prec Then begin  //es menor que la que sigue, expres.
      Result := Op1;  //solo devuelve el único operando que leyó
      exit;
    End;
{    //--------------------coger operador ---------------------------
	//operadores unitarios ++ y -- (un solo operando).
    //Se evaluan como si fueran una mini-expresión o función
	if opr1.id = op_incremento then begin
      case Op1.catTyp of
        t_integer: Cod_IncremOperanNumerico(Op1);
      else
        GenError('Operador ++ no es soportado en este tipo de dato.',PosAct);
        exit;
      end;
      opr1 := cogOperador; if pErr.HayError then exit;
      if opr1.id = Op_ninguno then begin  //no sigue operador
        Result:=Op1; exit;  //termina ejecucion
      end;
    end else if opr1.id = op_decremento then begin
      case Op1.catTyp of
        t_integer: Cod_DecremOperanNumerico(Op1);
      else
        GenError('Operador -- no es soportado en este tipo de dato.',PosAct);
        exit;
      end;
      opr1 := cogOperador; if pErr.HayError then exit;
      if opr1.id = Op_ninguno then begin  //no sigue operador
        Result:=Op1; exit;  //termina ejecucion
      end;
    end;}
    //--------------------coger segundo operando--------------------
    Op2 := GetOperandP(Opr1.jer);   //toma operando con precedencia
    debugln(space(ExprLevel)+' Op2='+Op2.txt);
    if pErr.HayError then exit;
    //prepara siguiente operación
    Evaluar(Op1, opr1, Op2);    //evalua resultado en "res"
    Op1 := res;
    if PErr.HayError then exit;
    cIn.SkipWhites;
    opr1 := Op1.GetOperator;   {lo toma ahora con el tipo de la evaluación Op1 (opr1) Op2
                                porque puede que Op1 (opr1) Op2, haya cambiado de tipo}
  end;  //hasta que ya no siga un operador
  Result := Op1;  //aquí debe haber quedado el resultado
end;
procedure TCompilerBase.GetExpression(const prec: Integer; isParam: boolean = false
    //indep: boolean = false
    );
{Envoltura para GetExpressionCore(). Se coloca así porque GetExpressionCore()
tiene diversos puntos de salida y Se necesita llamar siempre a expr_end() al
terminar.
Toma una expresión del contexto de entrada y devuelve el resultado em "res".
"isParam" indica que la expresión evaluada es el parámetro de una función.
"indep", indica que la expresión que se está evaluando es anidada pero es independiente
de la expresion que la contiene, así que se puede liberar los registros o pila.
}
{ TODO : Para optimizar debería existir solo GetExpression() y no GetExpressionCore() }
begin
  Inc(ExprLevel);  //cuenta el anidamiento
  debugln(space(ExprLevel)+'>Inic.expr');
  if OnExprStart<>nil then OnExprStart(ExprLevel);  //llama a evento
  res := GetExpressionCore(prec);
  if OnExprEnd<>nil then OnExprEnd(ExprLevel, isParam);    //llama al evento de salida
  debugln(space(ExprLevel)+'>Fin.expr');
  Dec(ExprLevel);
  if ExprLevel = 0 then debugln('');
end;
procedure TCompilerBase.GetBoolExpression;
//Simplifica la evaluación de expresiones booleanas, validadno el tipo
begin
  GetExpression(0);  //evalua expresión
  if PErr.HayError then exit;
  if res.Typ.cat <> t_boolean then begin
    GenError('Se esperaba expresión booleana');
  end;
end;
{function GetNullExpression(): TOperand;
//Simplifica la evaluación de expresiones sin dar error cuando encuentra algún delimitador
begin
  if
  GetExpression(0);  //evalua expresión
  if PErr.HayError then exit;
end;}

constructor TCompilerBase.Create;
begin
  PErr.IniError;   //inicia motor de errores
  //Inicia lista de tipos
  types := TTypes.Create(true);
  //Inicia variables, funciones y constantes
  ClearAllVars;
  ClearAllFuncs;
  ClearAllConst;
  //crea el operador NULL
  nullOper := TOperator.Create;
  //inicia la sintaxis
  xLex := TSynFacilSyn.Create(nil);   //crea lexer
  CreateSysFunction('', nil, nil);  //crea la función 0, para uso interno

  if HayError then PErr.Show;
  cIn := TContexts.Create(xLex); //Crea lista de Contextos
  ejecProg := false;
end;
destructor TCompilerBase.Destroy;
begin
  cIn.Destroy; //Limpia lista de Contextos
  xLex.Free;
  nullOper.Free;
  types.Free;
  inherited Destroy;
end;

{ TOperand }

function TOperand.VarName: string; inline;
begin
  Result := vars[ivar].nom;
end;
procedure TOperand.Load; inline;
begin
  //llama al evento de carga
  if typ.OnLoad <> nil then typ.OnLoad(self);
end;
procedure TOperand.Push;
begin
  //llama al evento de pila
  if typ.OnPush <> nil then typ.OnPush(self);
end;
procedure TOperand.Pop;
begin
  //llama al evento de pila
  if typ.OnPop <> nil then typ.OnPop(self);
end;

function TOperand.FindOperator(const oper: string): TOperator;
//Recibe la cadena de un operador y devuelve una referencia a un objeto Toperator, del
//operando. Si no está definido el operador para este operando, devuelve nullOper.
begin
  Result := typ.FindOperator(oper);
end;
function TOperand.GetOperator: Toperator;
//Lee del contexto de entrada y toma un operador. Si no encuentra un operador, devuelve NIL.
//Si el operador encontrado no se aplica al operando, devuelve nullOper.
begin
//  cIn.SkipWhites;  No se debe usar "SkipWhites" aquí, porque el lenguaje podría requerir "SkipWhitesNOEOL"
  if cIn.tokType <> tkOperator then exit(nil);
  //hay un operador
  Result := typ.FindOperator(cIn.tok);
  cIn.Next;   //toma el token
end;
{Los métodos siguientes pueden depender de algunas variables (como registros
virtuales) si es que se implementa una suerte de Máquina Virtual integrada.
La versión que se implementa aquí, es para un compilador, que hace evaluación
de expresiones cuando los operandos son de tipo Cosntante.}
function TOperand.expres: string;
//Devuelve una cadena con un texto que representa el valor del operador. Depende de los
//estados de los oepradores que se haya definido. Se usa para generar texto de ayuda o código
//intermedio.
begin
{  case estOp of
//  NO_STORED:
  STORED_LIT: Result := typ.name + '(' + txt + ')';
  STORED_VAR: Result := typ.name + '(vars[' + IntToStr(ivar) + '])';
  STORED_ACU: Result := typ.name + '(A)';
  STORED_ACUB: Result := typ.name + '(B)';
  else Result := '???'
  end;}
end;
function TOperand.GetValBool: boolean;
begin
  case catOp of
  coConst   : Result := valBool;
  coVariab: Result := vars[ivar].valBool;
  coExpres  : Result := valBool;   //por norma, lo leemos de aquí.
  end;
end;
function TOperand.GetValInt: int64;
begin
  case catOp of
  coConst   : Result := valInt;
  coVariab: Result := vars[ivar].valInt;
  coExpres  : Result := valInt;   //por norma, lo leemos de aquí.
  end;
end;
function TOperand.GetValFloat: extended;
begin
  case catOp of
  coConst   : Result := valFloat;
  coVariab: Result := vars[ivar].valFloat;
  coExpres  : Result := valFloat;   //por norma, lo leemos de aquí.
  end;
end;
function TOperand.GetValStr: string;
begin
  case catOp of
  coConst   : Result := valStr;
  coVariab: Result := vars[ivar].valStr;
  coExpres  : Result := valStr;   //por norma, lo leemos de aquí.
  end;
end;

end.
