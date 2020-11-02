unit xmltest;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, xmldom, XMLIntf, msxmldom, XMLDoc;

type
  TForm_xml_test = class(TForm)
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    Edit1: TEdit;
    Button1: TButton;
    XMLDocument1: TXMLDocument;
    XMLDocument2: TXMLDocument;
    Edit2: TEdit;
    Memo2: TMemo;
    btn_open2: TButton;
    btn_reg: TButton;
    btn_sorted: TButton;
    btn_sort2: TButton;
    procedure Button1Click(Sender: TObject);
    procedure btn_open2Click(Sender: TObject);
    procedure btn_regClick(Sender: TObject);
    procedure btn_sortedClick(Sender: TObject);
    procedure btn_sort2Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form_xml_test: TForm_xml_test;

implementation

uses
  PerlRegEx,
  Unit_xml;

{$R *.dfm}

procedure TForm_xml_test.Button1Click(Sender: TObject);
var
  XMLFile : TXMLFile;
  disk_size : int64;
begin

  disk_size := 32*int64(1024*1024*1024);
  if  OpenDialog1.Execute then
  begin
    Edit1.Text  := OpenDialog1.FileName;
    XMLFile     := TXMLFile.Create(Edit1.Text, disk_size);   //磁盘尺寸定义为0.这个测试取消
    //XMLFile.XMLtype := enum_patch; //编程操作，  enum_write enum_patch
    XMLFile.Memo   := Memo2; 
    XMLFile.Active := True;

    XMLFile.Show_xml_Value;
    XMLFile.Show_xml_sorted;

  end;
end;

procedure TForm_xml_test.btn_open2Click(Sender: TObject);
var XMLFile : TXMLFile;
    disk_size : Int64;
begin
  disk_size := 32*int64(1024*1024*1024);
  if  OpenDialog1.Execute then
  begin
    Edit1.Text := OpenDialog1.FileName;
    XMLFile    := TXMLFile.Create(OpenDialog1.FileName,disk_size);//磁盘空间为零
    XMLFile.Memo := Memo1;
    XMLFile.Active := True;
    
  end;
end;

procedure TForm_xml_test.btn_regClick(Sender: TObject);
//查找是否存在
var
  reg: TPerlRegEx;
begin
  reg := TPerlRegEx.Create();
  //reg.Subject :=  '(512*NUM_DISK_SECTORS)-16896';
  reg.Subject := 'NUM_DISK_SECTORS-33';
  reg.RegEx   := 'NUM_DISK_SECTORS-(\d+)';
  

  if reg.Match then
  begin
    
    ShowMessage('找到了'+ reg.Groups[1]);

  end
  else
    ShowMessage('没找到');
  FreeAndNil(reg);

end;

procedure TForm_xml_test.btn_sortedClick(Sender: TObject);
var
  xml :  TXMLFile;
begin
  if  OpenDialog1.Execute then
  begin
    Edit1.Text :=  OpenDialog1.FileName;
    XML := TXMLFile.Create(OpenDialog1.FileName,0);  //磁盘空间为零
    XML.Memo   := Memo1;
    XML.Active := True;

    XML.Show_xml_Value;
    XML.Show_xml_sorted;
  end;
end;

procedure TForm_xml_test.btn_sort2Click(Sender: TObject);
var
  MyAddrRecList: TStartAddressList;
  tmp :  TMyAddrRec;
  s :string;
  i : integer;
begin

  MyAddrRecList := TStartAddressList.Create;
  
  for i := 9 downto 0 do
  begin
    tmp.filename := '';
    tmp.start_sector := i;
    MyAddrRecList.Add(tmp);
  end;

  MyAddrRecList.sort;  //测试地址排序，结果显示正确，TStartAddressList可以使用

  //输出
  for i := 0 to MyAddrRecList.Count - 1 do
  begin
    s :=   ' start_sector: ' + inttostr(MyAddrRecList[i].start_sector) + ' filename: '
         + MyAddrRecList[i].filename;
    Memo2.Lines.Append(s);
  end;

  FreeAndNil(MyAddrRecList);
  

end;

end.
