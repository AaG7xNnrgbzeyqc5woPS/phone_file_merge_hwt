unit Unit_xml;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, xmldom, XMLIntf, msxmldom, XMLDoc,
  Unit_FileCheck, public_type;

const

  //#emmc����ߴ�  //# 64TB - Terabytes
  EMMCBLD_MAX_DISK_SIZE_IN_BYTES : Int64 = 64 * 1024 * int64(1024*1024*1024);

  //#�ָ�ǰ������ļ��ߴ� 10M��ÿ��ֻд10M����ο�������ռ�ڴ棿
  // ���������ս��ȣ��ý��������û���ʾ
  MAX_FILE_SIZE_BEFORE_SPLIT : Int64 = (10*1024*1024);
  //#MAX_FILE_SIZE_BEFORE_SPLIT = (2048) # testing purposes
  

  
type
  PMyAddrRec =^TMyAddrRec;
  TMyAddrRec = type_xml;

  {
   //��������ʧ�ܣ���������
  TStartAddressList = class(TList)    //��������ʧ�ܣ���������
  private

    function Get(Index: Integer): PMyAddrRec;
  public
    xml_value_sorted  : array of TMyAddrRec;  //����ԭʼֵ�������ֵ��List�У�ֻ��ͨ��items���Է���

    constructor create();
    destructor Destroy; override;
    function Add(Value: PMyAddrRec): Integer; overload;
    function Add(Value: TMyAddrRec): Integer; overload;
    procedure copyfrom(source: array of TMyAddrRec);
    procedure copyfrom_filter(source: array of TMyAddrRec); //���˺󿽱�

    procedure sort;
    property  Items[Index: Integer]: PMyAddrRec read Get; default;
  end;
 }
  
  TSortAddr = class
  private
    FMinDiskSizeInSectors : Int64;
    Addr_sorted           : array of int64;

    procedure copyfrom(const source: array of TMyAddrRec); // source.startsec copyto Addr_sorted
    procedure SortByAddr(var AddrArray : array of Int64);

  public

    xml_value_sorted  : array of TMyAddrRec;

    constructor Create(); overload;
    constructor Create(const source: array of TMyAddrRec;  DiskSizeInBytes: Int64); overload;
    destructor  Destroy(); override;

    procedure Sort(const source: array of TMyAddrRec);
    //�������� Addr_sorted ������  Addr_sorted�Ĵ��򣬽� source �� xml_value_sorted

    function CalculateMinDiskSizeInSecter: Int64;
    class procedure ReLocation_StartAddr(var writedAddr: array of TMyAddrRec; DiskSizeInBytes: int64);

    property MinDiskSizeInSectors : Int64 read FMinDiskSizeInSectors;

  end;

  XML_type = (enum_write, enum_patch);
  Ttype_xml_array = array of type_xml;

  TXMLFile = class(TObject)
  private
    //������û������ӳ����̳ߴ磬����������Ӧ�ӳ���
    FDiskSizeInBytes : Int64;
    FXML_type : XML_type; //write,patch ����
  private
    FActive  : Boolean;
    FxmlFileName : string;
    FMemo: TMemo;

    xml_value   : Ttype_xml_array;


    function HandleNum_Disk_SECTORS_String(field: string): Int64;

    procedure ShowLog(s: string);           //�� memo����ʾ��־
    procedure SetActive(aValue: boolean);
    procedure SetMemo(aValue: TMemo);
    procedure GetAttrNodeValue(NodeNo: Integer; NodeName,Text: string);

  public
    xml_Sorted : TSortAddr;

    constructor Create; overload;
    constructor Create(FileName: string; DiskSizeInBytes: Int64); overload;

    // xml������Ľڵ�ֵ������  xml_value
    // ������ʼ��ַ�ӵ�ַ�ռ�ײ�����ģ� �Ѿ��ô�����������滻��
    // ��ַ��λ�� 64T֮�⣬Ϊ�˷�����������
    procedure ParseXML(xml_filename: string);  overload;
    procedure ParseXML; overload;

  private
    procedure show_xml_value(Memo: TMemo; Value: type_xml);  overload;
    procedure show_xml_value(memo: TMemo; value: array of type_xml; messge: string=''); overload;
  public
    procedure Show_xml_Value; overload; //�� memo����ʾ xml_value,������
    procedure Show_xml_sorted;          //xml_sorted�ڵ�ֵ��ֱ����ʾ���飬������Է��ʵ�




  public
    property xmlFileName: string  read FxmlFileName write FxmlFileName;
    property Active : Boolean read FActive write SetActive;
    property Memo : TMemo read FMemo write SetMemo;
    property XMLtype : XML_type read FXML_type write FXML_type; //write,patch ����
    property patch_value : Ttype_xml_array read xml_value;  //�Ѿ������� NUM_DISK_SECTORS-34�Ĳ������ü�¼��

  end;

  //�÷���
  // 1.  create object
  // 2.  setup memo  property
  // 3.  active := true;
  //   then auto execute ParseXML then  GetAttrNodeValue
  // 4. result in xml_value

  {-------------------------------------
  ����������
  ���� ��ͨ��xml�ļ�������ֵ��ʾ�� memo��
  var
    xml :  TXMLFile;
  begin
    if  OpenDialog1.Execute then
    begin
      XML := TXMLFile.Create(OpenDialog1.FileName);
      XML.Memo   := Memo1;
      XML.Active := True;  //���ʱ���Ѿ��������

      XML.Show_xml_Value;
      XML.Show_xml_sorted;
    end;
  end;
  //��ǰxml��¼�Ѿ���start_section���򣬲���ɾ�����ļ���Ϊ�գ�start_section < 0 �ļ�¼
  
  }


  //TListSortCompare
//  function SortCompare(Item1, Item2: Pointer):Integer;
  procedure copy_xml(source: type_xml; var dest: type_xml);

  

implementation

uses
  PerlRegEx, Merge, xmltest, Log;





//��Ҫ��ȫ�ֱ���  
var SECTOR_SIZE : Integer;

constructor TXMLFile.Create;
begin
  inherited;
  FXML_type := enum_write;
  FActive := false;
  FxmlFileName := '';
  SetLength(xml_value,0);

  SECTOR_SIZE     := 512;     // = 512; ȫ�ֱ���
  FDiskSizeInBytes := 0;       // Ҳ����singleimage.bin�ļ��Ĵ�С
end;

constructor TXMLFile.Create(FileName: string; DiskSizeInBytes: Int64);
begin
  Create;
  FxmlFileName     := FileName;
  FDiskSizeInBytes := DiskSizeInBytes;
end;


//xml�ؼ�����󣬾��Զ�����xml, ����ʼ��ַ����xml��Ŀ
procedure TXMLFile.SetActive(aValue: boolean);
begin
  if (aValue <>  FActive) and (Trim(FxmlFileName) <> '') then
  begin
    FActive    := aValue;
    ParseXML;
    
    if FXML_type = enum_write then
    begin
      xml_Sorted := TSortAddr.create(xml_value, FDiskSizeInBytes);
      MLog.PrintXMLValue(xml_value,'��������ļ���δ�����XMLֵ');
      MLog.PrintXMLValue(xml_Sorted.xml_value_sorted, '��������ļ����������xmlֵ');
      //�Ե�ַ����
    end
    else
    begin
       //�����ļ�����Ҫ���򣬶Ե������ļ����д򲹶�
       MLog.PrintXMLValue(xml_value,'���������ļ���ԭʼ��XMLֵ');
       TSortAddr.ReLocation_StartAddr(xml_value, FDiskSizeInBytes);
       MLog.PrintXMLValue(xml_value,'���������ļ����ض�λ��XMLֵ');
    end;
  end;
end;

procedure TXMLFile.SetMemo(aValue: TMemo);
begin
  if not Assigned(FMemo) then
     FMemo :=  aValue;
end;


procedure  TXMLFile.ParseXML;
begin
  ParseXML(FxmlFileName);
end;

procedure TXMLFile.ShowLog(s: string);  //�� memo����ʾ��־
begin
   if Assigned(FMemo) then
   begin
     FMemo.Lines.Append(s);
   end;
end;

//------------------------------------------------------
// xml������Ľڵ�ֵ������  xml_value
// ������ʼ��ַ�ӵ�ַ�ռ�ײ�����ģ� �Ѿ��ô�����������滻��
// ��ַ��λ�� 64T֮�⣬Ϊ�˷�����������
procedure  TXMLFile.ParseXML(xml_filename: string);
var
  RootNode, Node, AttrNode    : IXMLNode;
  NodeList : IXMLNodeList;
  i,j : integer;
  xml_ItemCount : integer;

  s: string;

  XMLDoc : TXMLDocument;
begin
   MLog.PrintFileSize(xml_filename);

   //TXMLDocument.Create ��Ҫһ��Fform �� owner���������
   //�ڶ��߳���Ҳ��Ǳ�����⣬��Ҫ���ڶ��߳���
   XMLDoc :=  TXMLDocument.Create(Application.MainForm);
   XMLDoc.FileName := xml_filename;
   XMLDoc.Active   := true;

  //   XMLDoc.

   RootNode := XMLDoc.DocumentElement;     //���ڵ�
   NodeList := RootNode.ChildNodes;        //�ڵ��б�
   xml_ItemCount :=   NodeList.Count;

   s := '���ڵ��µĽڵ���Ŀ��' + Inttostr(NodeList.Count);
   ShowLog(s);

   //xml_ItemCount := 8; //�ȶ�ȡ8����¼����
   setlength(xml_value, xml_ItemCount);
   for i := 0 to   xml_ItemCount - 1 do
   begin
     //if i = 175 then        // only for test
     // ShowMessage(IntToStr(i));

     Node :=  NodeList.Nodes[i];

     s := inttostr(i)+'�ڵ����ƣ�'+Node.NodeName +'�ڵ��ı�: ' + Node.Text;
     ShowLog('');
     ShowLog(s);

     //SECTOR_SIZE����̫��Ҫ�ˣ�����ȡ������  ����4K���γ���
     // SECTOR_SIZE :Integer; ȫ�ֱ���
     if not VarIsNull(Node.Attributes['SECTOR_SIZE_IN_BYTES']) then
     begin
       SECTOR_SIZE := StrToInt(Node.Attributes['SECTOR_SIZE_IN_BYTES']);
       xml_value[i].SECTOR_SIZE_IN_BYTES := SECTOR_SIZE;
     end;  

     for j := 0 to Node.AttributeNodes.Count - 1 do
     begin
       AttrNode := Node.AttributeNodes.Nodes[j];
       GetAttrNodeValue(i,AttrNode.NodeName, AttrNode.Text); //�ڵ�ֵ��xml_value
     end;

   end;

  FreeAndNil(XMLDoc);

end;

procedure TXMLFile.GetAttrNodeValue(NodeNo: Integer; NodeName, Text: string);
var
  reg: TPerlRegEx;
  s:string;
begin

   s := '  No: '+ inttostr(NodeNo) + ' Name: ' + NodeName + ' Text:'+Text;
   ShowLog(s);

       if  NodeName  = 'SECTOR_SIZE_IN_BYTES' then
       begin
          xml_value[NodeNo].SECTOR_SIZE_IN_BYTES := strtoint( Text);
          SECTOR_SIZE := xml_value[NodeNo].SECTOR_SIZE_IN_BYTES;  //�������������ߴ�
       end
       else if  NodeName = 'start_sector'  then
          xml_value[NodeNo].start_sector := HandleNum_Disk_SECTORS_String(Text)
       else if  NodeName  = 'start_byte_hex' then
          xml_value[NodeNo].start_byte_hex := 0   //no used, 

       else if  NodeName  = 'sparse' then
       begin
          xml_value[NodeNo].sparse := Bool( Text);
       end
       else if  NodeName  = 'size_in_KB' then
          xml_value[NodeNo].size_in_KB := 0    //no used;

       else if  NodeName  = 'physical_partition_number' then
          xml_value[NodeNo].physical_partition_number := strtoint(Text)

       else if  NodeName  = 'num_partition_sectors' then
          xml_value[NodeNo].num_partition_sectors := HandleNum_Disk_SECTORS_String(Text)

       else if  NodeName  = 'label' then
          xml_value[NodeNo].label_str :=  Text

       else if  NodeName  = 'filename' then
          xml_value[NodeNo].filename := Trim(Text)

       else if  NodeName  = 'file_sector_offset' then
          xml_value[NodeNo].file_sector_offset := HandleNum_Disk_SECTORS_String(Text)

       //�����ǲ���
       else if NodeName  = 'size_in_bytes' then
          xml_value[NodeNo].size_in_bytes :=  strtoint(Text)
       else if NodeName  = 'byte_offset' then
          xml_value[NodeNo].byte_offset :=  strtoint(Text)
       else if NodeName  = 'what' then
          xml_value[NodeNo].what :=  Text
       //�����ǲ���
       else if  NodeName  = 'value' then
       begin

         //1��ƥ��"NUM_DISK_SECTORS-(\d+)"
         reg := TPerlRegEx.Create();
         reg.RegEx   := 'CRC32\((\d+).?,(\d+).?\)';
         reg.Subject := Text;
         if reg.Match then
         begin
            xml_value[NodeNo].value := 0;
            xml_value[NodeNo].xml_function := 'CRC32';
            xml_value[NodeNo].arg0 := StrToInt(reg.Groups[1]);
            xml_value[NodeNo].arg1 := StrToInt(reg.Groups[2]);
           reg.Free;
           Exit;  //��ǰ�˳�����
         end
         else
         begin
           reg.RegEx   := 'CRC32\((NUM_DISK_SECTORS-\d+).?,(\d+).?\)';
           reg.Subject := Text;
           if reg.Match then
           begin
             xml_value[NodeNo].value:= 0;
             xml_value[NodeNo].xml_function := 'CRC32';
             xml_value[NodeNo].arg0 := HandleNum_Disk_SECTORS_String(reg.Groups[1]);
             xml_value[NodeNo].arg1 := StrToInt(reg.Groups[2]);
             reg.Free;
             Exit;  //��ǰ�˳�����
           end
           else
           begin
              xml_value[NodeNo].value:= HandleNum_Disk_SECTORS_String(Text);
           end;
             reg.Free;
         end;
       end;
end;


//-------------------------------------------------------
//���������ȫ���Ĵ���  Num_Disk_SECTORS ������д���
//���� ���̴�С����ͳһ������������Դ��̴�С��һ������
//�������һ�㣬���� �������̣��������
function TXMLFile.HandleNum_Disk_SECTORS_String(field: string): Int64;
var
  reg: TPerlRegEx;
  Max_disk_in_sec : Int64; //����һ���޴������
begin
  Max_disk_in_sec := EMMCBLD_MAX_DISK_SIZE_IN_BYTES div SECTOR_SIZE;

  //1��ƥ��"NUM_DISK_SECTORS-(\d+)"
  reg := TPerlRegEx.Create();
  reg.RegEx   := 'NUM_DISK_SECTORS-(\d+)';
  reg.Subject := field;
   if reg.Match then
   begin
     Result := Max_disk_in_sec + strtoint64(reg.Groups[1]);
     reg.Free;
     Exit;  //��ǰ�˳�����
   end
   else
     reg.Free;

  //2, ƥ�� NUM_DISK_SECTORS ����
  reg := TPerlRegEx.Create();
  reg.RegEx   := 'NUM_DISK_SECTORS';
  reg.Subject := field;

  if  reg.Match then
  begin
    Result := Max_disk_in_sec;
    reg.Free;
    Exit;
  end
  else
    reg.Free;

  //3, ʣ�µľ�����ͨ����
  Result := StrToInt64(field);
end;


procedure TXMLFile.show_xml_value(Memo: TMemo; Value: array of type_xml; messge: string='');
var i :Integer;
begin
    Memo.Lines.Add('');
    Memo.Lines.Add('');
    Memo.Lines.Add('');
    Memo.Lines.Add('');
    Memo.Lines.Add('');
    Memo.Lines.Add('');
    Memo.Lines.Add('-------------------------------------------------------------------');
    Memo.Lines.Add('-----------------------------------------------------------------------');
    Memo.Lines.Add('--------------------------------------------------------------------------------');
    Memo.Lines.Add('------------------------------------------------------------------------------------------');
    Memo.Lines.Add('------' + messge);
    for i := 0 to High(Value) do
    begin
      Memo.Lines.Append('');
      Memo.Lines.Append('NodeIndex: ' + IntToStr(i));
      show_xml_value(Memo,Value[i]);
      MLog.PrintXMLValue(Value[i]);
    end;
end;

procedure TXMLFile.show_xml_value(Memo: TMemo; Value: type_xml);
begin
  with  Memo.Lines, Value do
    begin
      Append('  start_sector: ' + IntToStr(start_sector));
      Append('  file_sector_offset: ' + IntToStr(file_sector_offset));
      Append('  num_partition_sectors: ' + IntToStr(num_partition_sectors));
      Append('  SECTOR_SIZE_IN_BYTES:  ' + IntToStr(SECTOR_SIZE_IN_BYTES));
      Append('  physical_partition_number: ' + IntToStr(physical_partition_number));
      Append('  start_byte_hex: ' + IntToStr(start_byte_hex));
      Append('  label: ' + label_str);
      Append('  filename: ' + filename);

      //������ ����ר��
      Append('  xml_function: ' + xml_function);
      Append('  value: ' + IntToStr(value));
      Append('  arg0: ' + IntToStr(arg0));
      Append('  arg1: ' + IntToStr(arg1));


    {
       //���²���ר��
     xml_function : string;   //CRC32
     value        : Int64;
     arg0         : Int64;   //start section
     arg1         : Int64;   //length
     }
      

    end;
end;


procedure TXMLFile.Show_xml_Value;
var s: string;
begin
  s := '----- ������ʾxml_sorted.xml_value -----------';
  Show_xml_value(Memo,xml_value, s);
end;

procedure TXMLFile.Show_xml_sorted; //xml_sorted�ڵ�ֵ��ֱ����ʾ���飬������Է��ʵ�
var s: string;
begin
  //xml_sorted.xml_value_sorted;
  s := '----- ��ʾxml_sorted.xml_value_sorted-----------';
  show_xml_value(Memo, xml_sorted.xml_value_sorted, s);
end;


//---------------------------------------------------------------------
//              TStartAddressList
//---------------------------------------------------------------------
(*
constructor TStartAddressList.create();
begin
  //inherited create();
  inherited;
  SetLength(xml_value_sorted,0);
end;


function TStartAddressList.Add(Value: PMyAddrRec): Integer;
begin
  Result := inherited Add(Value);
end;

destructor TStartAddressList.Destroy;
//var
//  i: Integer;
begin
  //SetLength(xml_value_sorted,0);  //�ͷſռ�
  xml_value_sorted := nil;    //�ͷſռ�
  {
  for i := 0 to Count - 1 do
  begin
    Items[i].filename  := '';
    Items[i].label_str := '';
    FreeMem(Items[i]);
  end;
  }
  inherited;
end;

function TStartAddressList.Add(Value: TMyAddrRec): Integer;
var len :integer;
    pNewRec :  PMyAddrRec;
begin
  //����һ�����ݿռ�
  len :=  Length(xml_value_sorted)+1;
  SetLength(xml_value_sorted , len);

  //���������һ���ռ�
  copy_xml(Value, xml_value_sorted[len-1]);   //����ֵ���µĿռ�
  //xml_value_sorted[i-1] := Value;           //����һ�ַ�ʽ��ֱ�Ӹ�ֵ

  pNewRec := @xml_value_sorted[len-1];
  Result := Add(pNewRec);                   //�½ڵ�ӵ� �б���
end;


procedure TStartAddressList.copyfrom(source: array of TMyAddrRec);
var i: Integer;
begin
  for i := 0 to Length(source) - 1 do
    Add(source[i]);
end;

procedure TStartAddressList.copyfrom_filter(source: array of TMyAddrRec); //���˺󿽱�
var i: Integer;
begin
  //�޳� ���ļ���
  //�޳��ļ�����Ϊ���
  //�޳� ��ʼ����Ϊ������
  //ʵ���ļ����� ���ڷ���ĳ��ȵģ����棡
  //

  for i := 0 to Length(source) - 1 do
  begin
    if length(Trim(source[i].filename)) <= 0 then
      Continue;

    if source[i].start_sector < 0 then
      Continue;

    Add(source[i]);

  end;
end;




function TStartAddressList.Get(Index: Integer): PMyAddrRec;
begin
  Result := PMyAddrRec(inherited Get(Index));
end;

procedure TStartAddressList.sort;
begin

  inherited sort(SortCompare);
end;


function SortCompare(Item1, Item2: Pointer):Integer;

var a,b,c: Int64;
begin
  a := TMyAddrRec(Item1^).start_sector;
  b := TMyAddrRec(Item2^).start_sector;
  c := a-b;


  if c > 0 then
    Result := 1
  else if c < 0 then
    Result := -1
  else
    result := 0;
end;
*)

procedure copy_xml(source: type_xml; var dest: type_xml);
begin
  dest.label_str          := source.label_str;
  dest.filename           := source.filename;
  dest.file_sector_offset := source.file_sector_offset;
  dest.start_sector       := source.start_sector;
  dest.num_partition_sectors      := source.num_partition_sectors;
  dest.SECTOR_SIZE_IN_BYTES       := source.SECTOR_SIZE_IN_BYTES;
  dest.physical_partition_number  := source.physical_partition_number;
  dest.start_byte_hex     := source.start_byte_hex;
  dest.sparse             := source.sparse;
  dest.size_in_KB         := source.size_in_KB;

  dest.xml_function   := source.xml_function;
  dest.value          := source.value;
  dest.arg0           := source.arg0;
  dest.arg1           := source.arg1;
  dest.size_in_bytes  := source.size_in_bytes;

end;

//--------------------------------------------------------------
//                 TSortAddr
// �� AddrArray �е�������С����������� AddrArray

procedure TSortAddr.SortByAddr(var AddrArray : array of Int64);
var
  tmp : Int64;
  i,j : integer;
begin
  for i :=0 to Length(AddrArray)-2 do
  begin
    tmp := AddrArray[i];
    for j:= i+1 to Length(AddrArray)-1 do
    begin
      if tmp > AddrArray[j] then
      begin
        AddrArray[i] := AddrArray[j];
        AddrArray[j] := tmp;
      end;
    end;
  end;
end;

procedure TSortAddr.copyfrom(const source: array of TMyAddrRec);
var
  Len_source, len_dest: integer;
  i : integer;
begin
  Len_source := Length(source);

  for i := 0 to Len_source - 1 do
  begin
    if Length(source[i].filename) <= 0 then Continue;
    if source[i].start_sector < 0 then Continue;
    //if source[i].num_partition_sectors <=0 then Continue;
    if source[i].physical_partition_number >0 then Continue;
    //if source[i].file_sector_offset > 0 then Continue;

    //�ҵ�һ���Ϸ��ļ�¼�����ӵ� Addr_sorted ׼������
    len_dest :=  Length(Addr_sorted)+1;
    SetLength(Addr_sorted, len_dest);
    
    Addr_sorted[len_dest-1] := source[i].start_sector;  //������ʼ��������
  end;
end;

//source ��������� xml_value_sorted
procedure TSortAddr.Sort(const source: array of TMyAddrRec);
var
  i,j: Integer;

//���ص�ַ���ڼ�¼��������  
function FindAddr(Addr: Int64; const source: array of TMyAddrRec): Integer;
var i: integer;
begin
  Result := -1; //δ�ҵ�
  for i := 0 to Length(source)-1 do
  begin
    if Length(source[i].filename) <= 0 then   Continue;
    if source[i].start_sector < 0 then Continue;
    //if source[i].num_partition_sectors <= 0 then Continue;

    if Addr = source[i].start_sector then
    begin
      Result := i;
      Exit;         //�ҵ�һ�������˳���������������ַ��ͬ
    end;
  end;
end;

begin
  //1.
  copyfrom(source);

  //2.
  SortByAddr(Addr_sorted);

  //3.
  //���������ļ�¼����
  SetLength(xml_value_sorted, Length(Addr_sorted));

  for i := 0 to Length(Addr_sorted)-1 do
  begin
    j := FindAddr(Addr_sorted[i], source);    //��Դ��¼���� ָ����ַ�ļ�¼��
    copy_xml(source[j], xml_value_sorted[i]);
  end;

end;


constructor TSortAddr.create();
begin
  inherited;
  xml_value_sorted := nil;
  Addr_sorted := nil;
end;

destructor TSortAddr.destroy();
begin
  xml_value_sorted := nil;
  Addr_sorted      := nil;
  inherited;
end;  

//�������ض�λ��ַ�б�
//���Ҽ�����С���̴�С�����ʵ�ʴ��̳ߴ�С�����ͱ���
constructor TSortAddr.create(const source: array of TMyAddrRec; DiskSizeInBytes: Int64);
const msg = 'Ŀ��оƬ�ռ�̫С���޷��������е��ļ���';
const Gbytes = int64(1024*1024*1024);
var
  min_size : Single;
  msg_min_size: string;

begin
  create();
  Sort(source);  //����Ľ���� xml_value_sorted
  //����Ҫ�����ض�λ�����ݴ���DiskSizeInBytes
  if DiskSizeInBytes > 0 then
    ReLocation_StartAddr(xml_value_sorted, DiskSizeInBytes);
    //�����¶�λһ�£��ڼ�����С���̿ռ䣬�е����ѽ,����ͬ��ͨ���㷨һ���ˡ�
    
  FMinDiskSizeInSectors := CalculateMinDiskSizeInSecter;

  min_size := FMinDiskSizeInSectors * SECTOR_SIZE / Gbytes;
  msg_min_size := FloatToStrF(min_size,ffGeneral, 5, 2);

  if FMinDiskSizeInSectors <= DiskSizeInBytes div  SECTOR_SIZE then
    ReLocation_StartAddr(xml_value_sorted, DiskSizeInBytes)
  else
  begin
    msg_min_size := ' ��Ҫ����С�ߴ磺' + msg_min_size + 'GB!';
    ShowMessage(msg +  msg_min_size);
    raise Exception.Create(msg);
  end;
end;

class procedure TSortAddr.Relocation_StartAddr(var writedAddr: array of TMyAddrRec; DiskSizeInBytes: int64);
var i  :integer;
    Max_disk_in_sec : Int64; //����һ���޴������,���֧�ֵĴ��̴�С 64TB
    StartAddr_Reverse : Int64; //�ӿռ�ײ����� ��������ʼ��ַ
    DiskSizeInSec : Int64;

    function Relocation(Addr: int64): Int64;
    begin
      Result := Addr;
      if Addr >  Max_disk_in_sec  then
      begin
        DiskSizeInSec     := DiskSizeInBytes div SECTOR_SIZE;
        StartAddr_Reverse := Addr - Max_disk_in_sec;
        Result            := DiskSizeInSec - StartAddr_Reverse;
      end
    end;

begin
  Max_disk_in_sec := EMMCBLD_MAX_DISK_SIZE_IN_BYTES div SECTOR_SIZE;

  for i := 0 to Length(writedAddr) - 1 do
  begin
    writedAddr[i].start_sector := Relocation(writedAddr[i].start_sector);
    writedAddr[i].num_partition_sectors := Relocation(writedAddr[i].num_partition_sectors);
    writedAddr[i].value := Relocation(writedAddr[i].value);
    writedAddr[i].file_sector_offset := Relocation(writedAddr[i].file_sector_offset);
    //writedAddr[i].arg0  := Relocation(writedAddr[i].arg0);��ͨ���û�д���û����һ��
  end;
end;


//---------------------------------------------------------
//����num_partition_sectors����������С���̳ߴ�
//���Ҷ�λ������������ʼλ�ã���gpt_backup����
// ����ռ���оƬĿ��ռ�Ĵ�С
function TSortAddr.CalculateMinDiskSizeInSecter: Int64;
var MinDiskSizeInSectors, startsec, num_sec : Int64;
    i : integer;
    EMMCBLD_MAX_DISK_SIZE_IN_SECTOR: Int64;
    s :string;
begin
  MinDiskSizeInSectors := 0;
  EMMCBLD_MAX_DISK_SIZE_IN_SECTOR := EMMCBLD_MAX_DISK_SIZE_IN_BYTES div SECTOR_SIZE;

  MLog.BytesPerSector := SECTOR_SIZE;
  
  MLog.PrintSpaceLine;
  MLog.device_log('��ʼ���� ��С���̿ռ䣬MinDiskSizeInSectors');
  s := Format('1, �ۼ���ͨ������max(startsec[i]+num_sec[i]),i=0..%d ', [Length(xml_value_sorted)-1]);
  MLog.device_log(s);
  s :=  ' ��ʽ���ͣ���ʼ�������Ѿ����򣬺������ʼ������Խ��Խ����ʵֻҪ��ȡ���һ�������Ϳ����ˣ�'
      + ' ��ȻҪȥ����ʼ����С�ڵ���0, ��ʼ��������EMMCBLD_MAX_DISK_SIZE_IN_SECTOR��������� ��';
  MLog.device_log(s);

  for i := 0 to  Length(xml_value_sorted)-1 do
  begin
    startsec := xml_value_sorted[i].start_sector;
    num_sec  := xml_value_sorted[i].num_partition_sectors;
    if (startsec>0) and (startsec < EMMCBLD_MAX_DISK_SIZE_IN_SECTOR) then
    begin
      MinDiskSizeInSectors := startsec + num_sec;
      //��ʼ�������Ѿ����򣬺������ʼ������Խ��Խ��

      MLog.PrintMinDiskSizeInSecter(i, startsec, num_sec, MinDiskSizeInSectors);
    end;
  end;

  //# second time is for NUM_DISK_SECTORS-33 type of scenarios, since they will currently have
  //# my made up value of EMMCBLD_MAX_DISK_SIZE_IN_BYTES+start_sector
  //# ���˷ѽ��EMMCBLD_MAX_DISK_SIZE_IN_BYTES+start_sector �ǳ��������Զ���ģ������⺬��

  s := Format('2, �ۼ����������max(startsec[i]+num_sec[i]), i=0..%d', [Length(xml_value_sorted)-1]);
  MLog.device_log(s);
  for i := 0 to  Length(xml_value_sorted)-1 do
  begin
    startsec := xml_value_sorted[i].start_sector;
    if (startsec>0) and (startsec > (EMMCBLD_MAX_DISK_SIZE_IN_SECTOR)) then
    begin
      num_sec := (startsec - EMMCBLD_MAX_DISK_SIZE_IN_SECTOR);
      Inc(MinDiskSizeInSectors, num_sec);
      MLog.PrintMinDiskSizeInSecter(i, startsec, num_sec, MinDiskSizeInSectors);
    end;
  end;

  MLog.device_log('���� ��С���̿ռ���㣬MinDiskSizeInSectors');
  MLog.PrintSpaceLine;

  Result :=  MinDiskSizeInSectors;
end;

end.
