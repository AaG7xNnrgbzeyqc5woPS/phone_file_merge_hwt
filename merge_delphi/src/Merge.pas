unit Merge;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Buttons,
  XMLDoc, xmldom, XMLIntf, msxmldom;

const
  MAX_FILES = 16;
  SPACE     = 20;

  //block(partition) type number, table 3
  PAR_USER          = 0;
  PAR_BOOT0         = 1;
  PAR_BOOT1         = 2;
  PAR_RPMB          = 3;
  PAR_GP0           = 4;
  PAR_GP1           = 5;
  PAR_GP2           = 6;
  PAR_GP3           = 7;
  
  MAX_PARTITION     = 8;      // mean is partition type maxvalue. see PAR_NAME

  PAR_NAME : array [0..MAX_PARTITION - 1] of String =(
    'User',
    'Boot0',
    'Boot1',
    'RPMB',
    'GP1',
    'GP2',
    'GP3',
    'GP4'
  );

  EXT_NAME : array [0..MAX_PARTITION - 1] of String =(
    'User',
    'Boot0',
    'Boot1',
    'RPMB',
    'GP1',
    'GP2',
    'GP3',
    'GP4'
  );

type
  TForm_Main = class(TForm)
    btnMerge: TButton;
    Label1: TLabel;
    Label2: TLabel;
    Button1: TButton;
    Button2: TButton;
    OpenDialog1: TOpenDialog;
    Label3: TLabel;
    SaveDialog1: TSaveDialog;
    btnMergeclass: TButton;
    Button3: TButton;
    btn_gaotong: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure btnMergeClick(Sender: TObject);
    procedure btnMergeclassClick(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure btn_gaotongClick(Sender: TObject);
  private

    Counter : DWord;     // counter of file item
    edAddress : Array of TEdit;
    cbPar : Array of TComboBox;
    edFileName : Array of TEdit;
    sbOpenFile : Array of TSpeedButton;

    procedure AddFile;
    procedure CheckInput;
    procedure ClearItem(index : Integer);
    procedure sbHandle(Sender : TObject);
    procedure HandleAddress(Sender : TObject);

    function checkfile(): boolean;
    function CheckEdit: boolean; //�����������ĺϷ���

    { Private declarations }
  public
    { Public declarations }
  end;


var
  Form_Main: TForm_Main;

implementation

uses
  Unit_FileCheck, xmltest, Unit_xml;

{$R *.dfm}

procedure TForm_Main.FormCreate(Sender: TObject);
var i, j : Integer;
begin
  Caption := 'EMMC Merge utility Ver 1.2  2014-10-28';
  SetLength(edAddress, MAX_FILES);
  SetLength(edFileName, MAX_FILES);
  SetLength(cbPar, MAX_FILES);
  SetLength(sbOpenFile, MAX_FILES);


  for i := 0 to MAX_FILES - 1 do
  begin
    edAddress[i] := TEdit.Create(Self);
    with edAddress[i] do
    begin
      Top := 48 + i * 30;
      Left := 64;
      Width := 100;
      Height := 26;
      Parent := Self;
      tag := i;
      OnChange := HandleAddress;
    end;

    cbPar[i] := TComboBox.Create(Self);
    with cbPar[i] do
    begin
      Top := 48 + i * 30 ;
      Left := 64 + edAddress[i].Width + SPACE;
      Width := 80;
      Height := 26;
      Parent := Self;
    end;

    edFileName[i] := TEdit.Create(Self);
    with edFileName[i] do
    begin
      Top := 48 + i * 30 ;
      Left := 64 + cbPar[i].Width + Space + edAddress[i].Width + SPACE;
      Width := 280;
      Height := 26;
      Parent := Self;
    end;

    sbOpenFile[i] := TSpeedButton.Create(Self);
    with sbOpenFile[i] do
    begin
      Top := 48 + i * 30 ;
      Left := 64 + cbPar[i].Width + Space + edAddress[i].Width + SPACE + edFileName[i].Width + SPACE;
      Width := 23;
      Height := 22;
      Parent := Self;
      tag := i;
      OnClick := sbHandle;
      Caption := '>>';

    end;

  end;

  for i := 0 to MAX_FILES - 1 do
  begin
    for j := 0 to  MAX_PARTITION - 1 do
    begin
      cbPar[i].AddItem(PAR_NAME[j], nil);
    end;
    edAddress[i].Visible := False;
    cbPar[i].Visible := False;
    edFileName[i].Visible := False;
    sbOpenFile[i].Visible := False;
    cbPar[i].ItemIndex := 0;

  end;
  Counter := 0;
  AddFile;
end;

procedure TForm_Main.AddFile;
begin
  if  Counter < MAX_FILES then
  begin
    edAddress[Counter].Visible := True;
    edFileName[Counter].Visible := True;
    sbOpenFile[Counter].Visible := TRUE;
    cbPar[Counter].Visible := TRUE;
    Inc(Counter);
  end;
end;

procedure TForm_Main.FormDestroy(Sender: TObject);
begin
  SetLength(edAddress, 0);
  SetLength(edFileName, 0);
  SetLength(sbOpenFile, 0);
  SetLength(cbPar, 0);
end;

procedure TForm_Main.Button1Click(Sender: TObject);
begin
  AddFile;
end;

procedure TForm_Main.Button2Click(Sender: TObject);
var i : Integer;
begin
  for i := 0 to MAX_FILES - 1 do
  begin
    edAddress[i].Visible := False;
    cbPar[i].Visible := False;
    edFileName[i].Visible := False;
    sbOpenFile[i].Visible := False;

    edAddress[i].Text := '';
    edFileName[i].Text := '';
    cbPar[i].ItemIndex := 0;

  end;
  Counter := 0;
  AddFile;
end;

procedure TForm_Main.CheckInput;
var i : Integer;
begin
  for i := Counter - 1 downto 0 do
  begin
    if (Trim (edFileName[i].Text) = '') and (Trim(edAddress[i].Text) = '' ) then
    begin
      ClearItem(i);
    end else break;
  end;
end;

procedure TForm_Main.ClearItem(index : Integer);
begin
  edFileName[index].Visible := False;
  edAddress[Index].Visible := False;
  cbPar[index].Visible := False;
  sbOpenFile[index].Visible := False;
  Counter := index;
end;

//
procedure TForm_Main.HandleAddress(Sender: TObject);
var S : String;
begin
  S := UpperCase(TRIM(edAddress[TEdit(Sender).Tag].Text));
  if Length(S) <> 0 then
  begin
    if not (S[Length(S)] in ['0'..'9', 'A'..'F']) then
    begin
      Delete(S, Length(S), 1);
    end;
  end;
  edAddress[TEdit(Sender).Tag].Text := S;
  edAddress[TEdit(Sender).Tag].SelStart := Length(S);
end;

procedure TForm_Main.sbHandle(Sender : TObject);
var fname : String;
begin
  if OpenDialog1.Execute then
  begin
    fName := OpenDialog1.FileName;
    if FileExists(fName) then
      edFileName[TSpeedButton(Sender).Tag].Text := FName;
  end;
end;

function TForm_Main.checkfile(): boolean;
var
    i,j :integer;
    fs: TFileStream;
    SizeBound : Int64;
begin
   Result := False;
    for i := 0 to Counter - 1 do
    begin

      //1���ļ������Լ��
      if not FileExists(edFileName[i].Text) then
      begin
        ShowMessage('File : ' + EdFileName[i].Text + ' does not exist.');
        Result := True;
        Exit;
      end;

      //2�������ļ������߽�
      fs := TFileStream.Create(edFileName[i].Text, fmOpenRead);
      SizeBound := fs.Size + StrToInt64('$' + edAddress[i].Text);
      fs.Free;

      //3��ָ��Ŀ���ַ�Ϸ��Լ�飬��ʼ��ַ������512����������512�������ĳ���
      if StrToInt64('$' + edAddress[i].Text) mod 512 <> 0 then
      begin
        Result := True;
        ShowMessagePos ('Address  error.', 0 ,0);
        exit;
      end;

      //4�����Ŀ���ļ����ݿ��Ƿ�ᷢ���ص�
      for j := 0 to Counter - 1 do
      begin
        if (i <> j) and (StrToInt64('$' + edAddress[i].Text) < StrToInt64('$' + edAddress[j].Text)) then
        begin
          //ǰһ���ļ��Ľ�����ַ ���ں�һ���ļ�����ʼ��ַ���������ǣ�����
          if SizeBound > StrToInt64('$' + edAddress[j].Text) then
          begin
            Result := True;
            ShowMessage(IntToStr(j) + ' Error.');
          end;
        end;
      end;
    end;
end;

//-----------------------------------------------------------------------------

type
  BlockRec = packed record
    PartID: LongWord;     // partition ID,�������� {0..7}
    StartAddr: LongWord;  // Sector unit
    Size: LongWord;       // Sector unit
  end;

procedure TForm_Main.btnMergeClick(Sender: TObject);
var
  i,  tmp : Integer;
  fs, Outfs : TFileStream;
//  SizeBound,
  tmpInt64 : Int64;
  OutFName : String;
  Buffer : Array of Byte;
//  tmpDword : Dword;
  Block : Array of BlockRec;
Const
  Header : string = 'EMMC Compressed format'#$0A#$0D'Copyright (C) 2013 by Jobs Ju'#$0A#$0D#$1A;
begin
  CheckInput;

  if Counter = 0 then
  begin
    AddFile;
    ShowMessage('No data file loaded.');
    Exit;
  end;

  if not checkfile()then exit;
    SaveDialog1.Filter := '*.C.IMG|(*.C.IMG)';
    if SaveDialog1.Execute then
    begin
      OutFName := SaveDialog1.FileName;
      if ExtractFileExt(OutFName) = '' then
        OutFName := OutFName + '.C.IMG';

      if (not FileExists(OutFName))
       or (MessageDlg(('Do you really want to overwrite ' + ExtractFileName(OutFName) + '?'),
                      mtConfirmation, [mbYes, mbNo], 0) = IDYes) then
      begin
      
        Outfs := TFileStream.Create(OutFName, fmCreate);
        
        //1��д�ļ�ͷ
        SetLength(Buffer, $80);                 //������ $80 = 128�ֽ�
        Outfs.Write(Header[1], $80);            //�ļ�ͷ��дǩ������Header :string,  �ļ�ͷȫ�� 128�ֽڣ�Ŀǰֻдǩ����Ϣ

        //2��д������
        //2.0 д��������������

        Outfs.Write(Counter, SizeOf(Counter));  // ���ݿ����������ܿ����� Counter Dword ��4�ֽ� ��blocks/partitions count
        //2.1 ��д���������ݽṹ
        SetLength(Block, Counter); // partition total number(amount)   ��������
        for i := 0 to Counter - 1 do
        begin
          Block[i].PartID := LongWord(cbPar[i].ItemIndex); //�������� {0..7}

          fs := TFileStream.Create(edFileName[i].Text, fmOpenRead);
          tmpInt64 := fs.Size;
          fs.Free;

          //���㱣���ļ�����Ҫ�����������һ���������������������
          //
          Block[i].Size := tmpInt64 div 512;
          if tmpInt64 mod 512 <> 0 then
            Block[i].Size := Block[i].Size + 1;

          tmpInt64 := StrToInt64('$' + edAddress[i].Text);   //Ŀ�����ݵ���ʼ��ַ
          Block[i].StartAddr := tmpInt64 div 512 ;           //�������ű�ʾ
        end;
        
        //2.2����������������ļ�
        Outfs.Write(Block[0] , Counter * SizeOf(BlockRec));

        //3 
        for i := 0 to Counter - 1 do
        begin
          fs := TFileStream.Create(edFileName[i].Text, fmOpenRead);
          Outfs.CopyFrom(fs, fs.size);  //һ��һ��Դ�ļ����������Ŀ���ļ���
          tmpInt64 := fs.Size;
          fs.Free;

          //�ļ����Ȳ���512�ֽڵ������ģ����һ������ʣ�µ��ֽ�����
          tmpInt64 := tmpInt64 mod 512;
          if tmpInt64 <> 0 then
          begin
            tmp := 512 - tmpInt64;
            SetLength(Buffer, tmp);
            FillChar(Buffer[0], tmp, 0);
            Outfs.Write(Buffer[0], tmp);
          end;
        end;
        Outfs.Free;
      end;
    end;
 
end;



procedure TForm_Main.btnMergeclassClick(Sender: TObject);
var
  Merge : TMergeFile;
  out_fs  : string;
  i       : Integer;
  fname   : string;
  addr    : Int64;
  partid  : UInt32;
begin

  if not CheckEdit then
  begin
    showmessage('����Ĳ������ڴ���');
    exit;
  end;

  out_fs := 'd:\singleimg.bin';
  
  Merge := TMergeFile.Create(out_fs, Counter);

  SetLength(Merge.FInputFile, counter);

  for i := 0 to counter-1 do
  begin
    fname :=  edFileName[i].Text;
    Addr  := Int64(StrToInt64('$' + edAddress[i].Text));
    partid := cbPar[i].ItemIndex;

    Merge.FInputFile[i] := TFileCheck.Create(fname, Addr, partid );
    //Merge.FInputFile[i].CheckFile;
  end;

  Merge.DoMerge;
  FreeAndNil(Merge);
end;

function TForm_Main.CheckEdit: boolean;
var i : integer;
begin
  result := true;
  for i := 0 to counter-1 do
  begin
    if     (trim(edFileName[i].Text) = '')
       or (trim(edAddress[i].Text) = '')
       or (cbPar[i].ItemIndex < 0) then
    begin
      result := false;
      exit;
    end;

  end;
end;

procedure TForm_Main.Button3Click(Sender: TObject);
begin
  Form_xml_test.ShowModal;
end;

procedure TForm_Main.btn_gaotongClick(Sender: TObject);
var
  xml :  TXMLFile;
  Merge : TMergeFile;


  out_fs  : string;
  i       : Integer;
  fname   : string;
  addr    : Int64;
  partid  : UInt32;

  total   : int32;

  tmp : TMyAddrRec;
begin
  OpenDialog1.Filter := '*.xml|*.xml';
  if  OpenDialog1.Execute then
  begin
    XML        := TXMLFile.Create(OpenDialog1.FileName, 0);//���̿ռ�Ϊ0
    XML.Active := True;
    total      := Length(XML.xml_Sorted.xml_value_sorted);

    out_fs := 'd:\singleimg.bin';
    Merge := TMergeFile.Create(out_fs, total);
    SetLength(Merge.FInputFile, total);

    for i := 0 to total-1 do
    begin
      tmp     := XML.xml_Sorted.xml_value_sorted[i];
      fname   := tmp.filename;
      Addr    := tmp.start_sector;
      partid  := tmp.physical_partition_number;
      Merge.FInputFile[i] := TFileCheck.Create(fname, Addr, partid);
    end;
    XML.Free;

    Merge.DoMerge;
    FreeAndNil(Merge);
  end;

end;



end.
