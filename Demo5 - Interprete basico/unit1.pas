unit Unit1;
{
Ejemplo sencillo de intérprete que trabaja en una sintaxis parecida a la de Pascal.
Usa la librería Xpres, para la implementación.

Por Tito Hinostroza  14/0/2015
}
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, FileUtil, SynEdit, Forms, Controls, Graphics, Dialogs,
  StdCtrls, Parser, FormOut;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    edXpr: TSynEdit;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation
{$R *.lfm}

procedure TForm1.Button1Click(Sender: TObject);
begin
  cxp.Compilar('', edXpr.Lines);
  if cxp.HayError then begin
    If cxp.ErrorLine <> 0 Then begin
      edXpr.CaretX:=cxp.ErrorCol;
      edXpr.CaretY:=cxp.ErrorLine;
      edXpr.Invalidate;
    end;
    cxp.ShowError;
    edXpr.SetFocus;
  end else begin
    frmOut.Show;  //muestra consola
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  edXpr.Highlighter := cxp.xlex;
end;

end.

