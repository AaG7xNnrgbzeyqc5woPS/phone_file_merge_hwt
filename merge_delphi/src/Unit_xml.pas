unit Unit_xml;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, xmldom, XMLIntf, msxmldom, XMLDoc,
  Unit_FileCheck, public_type;

const

  //#emmc最大块尺寸  //# 64TB - Terabytes
  EMMCBLD_MAX_DISK_SIZE_IN_BYTES : Int64 = 64 * 1024 * int64(1024*1024*1024);

  //#分割前的最大文件尺寸 10M，每次只写10M，多次拷贝，少占内存？
  // 还可以掌握进度，用进度条给用户提示
  MAX_FILE_SIZE_BEFORE_SPLIT : Int64 = (10*1024*1024);
  //#MAX_FILE_SIZE_BEFORE_SPLIT = (2048) # testing purposes
  

  
type
  PMyAddrRec =^TMyAddrRec;
  TMyAddrRec = type_xml;

  {
   //这个类调试失败，放弃不用
  TStartAddressList = class(TList)    //这个类调试失败，放弃不用
  private

    function Get(Index: Integer): PMyAddrRec;
  public
    xml_value_sorted  : array of TMyAddrRec;  //保存原始值，排序的值在List中，只能通过items属性访问

    constructor create();
    destructor Destroy; override;
    function Add(Value: PMyAddrRec): Integer; overload;
    function Add(Value: TMyAddrRec): Integer; overload;
    procedure copyfrom(source: array of TMyAddrRec);
    procedure copyfrom_filter(source: array of TMyAddrRec); //过滤后拷贝

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
    //首先排序 Addr_sorted ，依据  Addr_sorted的次序，将 source 送 xml_value_sorted

    function CalculateMinDiskSizeInSecter: Int64;
    class procedure ReLocation_StartAddr(var writedAddr: array of TMyAddrRec; DiskSizeInBytes: int64);

    property MinDiskSizeInSectors : Int64 read FMinDiskSizeInSectors;

  end;

  XML_type = (enum_write, enum_patch);
  Ttype_xml_array = array of type_xml;

  TXMLFile = class(TObject)
  private
    //这个是用户输入的映像磁盘尺寸，具体计算见对应子程序
    FDiskSizeInBytes : Int64;
    FXML_type : XML_type; //write,patch 两种
  private
    FActive  : Boolean;
    FxmlFileName : string;
    FMemo: TMemo;

    xml_value   : Ttype_xml_array;


    function HandleNum_Disk_SECTORS_String(field: string): Int64;

    procedure ShowLog(s: string);           //在 memo中显示日志
    procedure SetActive(aValue: boolean);
    procedure SetMemo(aValue: TMemo);
    procedure GetAttrNodeValue(NodeNo: Integer; NodeName,Text: string);

  public
    xml_Sorted : TSortAddr;

    constructor Create; overload;
    constructor Create(FileName: string; DiskSizeInBytes: Int64); overload;

    // xml解析后的节点值保存在  xml_value
    // 扇区起始地址从地址空间底部计算的， 已经用大的数字数字替换，
    // 地址定位到 64T之外，为了方便后面的排序
    procedure ParseXML(xml_filename: string);  overload;
    procedure ParseXML; overload;

  private
    procedure show_xml_value(Memo: TMemo; Value: type_xml);  overload;
    procedure show_xml_value(memo: TMemo; value: array of type_xml; messge: string=''); overload;
  public
    procedure Show_xml_Value; overload; //在 memo中显示 xml_value,测试用
    procedure Show_xml_sorted;          //xml_sorted内的值，直接显示数组，这个可以访问的




  public
    property xmlFileName: string  read FxmlFileName write FxmlFileName;
    property Active : Boolean read FActive write SetActive;
    property Memo : TMemo read FMemo write SetMemo;
    property XMLtype : XML_type read FXML_type write FXML_type; //write,patch 两种
    property patch_value : Ttype_xml_array read xml_value;  //已经解析过 NUM_DISK_SECTORS-34的补丁配置记录，

  end;

  //用法：
  // 1.  create object
  // 2.  setup memo  property
  // 3.  active := true;
  //   then auto execute ParseXML then  GetAttrNodeValue
  // 4. result in xml_value

  {-------------------------------------
  测试用例：
  解析 高通的xml文件，解析值显示在 memo中
  var
    xml :  TXMLFile;
  begin
    if  OpenDialog1.Execute then
    begin
      XML := TXMLFile.Create(OpenDialog1.FileName);
      XML.Memo   := Memo1;
      XML.Active := True;  //这个时候已经排序好了

      XML.Show_xml_Value;
      XML.Show_xml_sorted;
    end;
  end;
  //当前xml记录已经按start_section排序，并且删掉了文件名为空，start_section < 0 的记录
  
  }


  //TListSortCompare
//  function SortCompare(Item1, Item2: Pointer):Integer;
  procedure copy_xml(source: type_xml; var dest: type_xml);

  

implementation

uses
  PerlRegEx, Merge, xmltest, Log;





//重要的全局变量  
var SECTOR_SIZE : Integer;

constructor TXMLFile.Create;
begin
  inherited;
  FXML_type := enum_write;
  FActive := false;
  FxmlFileName := '';
  SetLength(xml_value,0);

  SECTOR_SIZE     := 512;     // = 512; 全局变量
  FDiskSizeInBytes := 0;       // 也就是singleimage.bin文件的大小
end;

constructor TXMLFile.Create(FileName: string; DiskSizeInBytes: Int64);
begin
  Create;
  FxmlFileName     := FileName;
  FDiskSizeInBytes := DiskSizeInBytes;
end;


//xml控件激活后，就自动解析xml, 按起始地址排序xml条目
procedure TXMLFile.SetActive(aValue: boolean);
begin
  if (aValue <>  FActive) and (Trim(FxmlFileName) <> '') then
  begin
    FActive    := aValue;
    ParseXML;
    
    if FXML_type = enum_write then
    begin
      xml_Sorted := TSortAddr.create(xml_value, FDiskSizeInBytes);
      MLog.PrintXMLValue(xml_value,'编程配置文件，未排序的XML值');
      MLog.PrintXMLValue(xml_Sorted.xml_value_sorted, '编程配置文件，已排序的xml值');
      //对地址排序，
    end
    else
    begin
       //补丁文件不需要排序，对单独的文件进行打补丁
       MLog.PrintXMLValue(xml_value,'补丁配置文件，原始的XML值');
       TSortAddr.ReLocation_StartAddr(xml_value, FDiskSizeInBytes);
       MLog.PrintXMLValue(xml_value,'补丁配置文件，重定位的XML值');
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

procedure TXMLFile.ShowLog(s: string);  //在 memo中显示日志
begin
   if Assigned(FMemo) then
   begin
     FMemo.Lines.Append(s);
   end;
end;

//------------------------------------------------------
// xml解析后的节点值保存在  xml_value
// 扇区起始地址从地址空间底部计算的， 已经用大的数字数字替换，
// 地址定位到 64T之外，为了方便后面的排序
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

   //TXMLDocument.Create 需要一个Fform 做 owner，否则出错
   //在多线程中也有潜在问题，不要用在多线程中
   XMLDoc :=  TXMLDocument.Create(Application.MainForm);
   XMLDoc.FileName := xml_filename;
   XMLDoc.Active   := true;

  //   XMLDoc.

   RootNode := XMLDoc.DocumentElement;     //根节点
   NodeList := RootNode.ChildNodes;        //节点列表
   xml_ItemCount :=   NodeList.Count;

   s := '根节点下的节点数目：' + Inttostr(NodeList.Count);
   ShowLog(s);

   //xml_ItemCount := 8; //先读取8个记录测试
   setlength(xml_value, xml_ItemCount);
   for i := 0 to   xml_ItemCount - 1 do
   begin
     //if i = 175 then        // only for test
     // ShowMessage(IntToStr(i));

     Node :=  NodeList.Nodes[i];

     s := inttostr(i)+'节点名称：'+Node.NodeName +'节点文本: ' + Node.Text;
     ShowLog('');
     ShowLog(s);

     //SECTOR_SIZE变量太重要了，先提取出来！  否则4K情形出错
     // SECTOR_SIZE :Integer; 全局变量
     if not VarIsNull(Node.Attributes['SECTOR_SIZE_IN_BYTES']) then
     begin
       SECTOR_SIZE := StrToInt(Node.Attributes['SECTOR_SIZE_IN_BYTES']);
       xml_value[i].SECTOR_SIZE_IN_BYTES := SECTOR_SIZE;
     end;  

     for j := 0 to Node.AttributeNodes.Count - 1 do
     begin
       AttrNode := Node.AttributeNodes.Nodes[j];
       GetAttrNodeValue(i,AttrNode.NodeName, AttrNode.Text); //节点值存xml_value
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
          SECTOR_SIZE := xml_value[NodeNo].SECTOR_SIZE_IN_BYTES;  //立即更新扇区尺寸
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

       //以下是补丁
       else if NodeName  = 'size_in_bytes' then
          xml_value[NodeNo].size_in_bytes :=  strtoint(Text)
       else if NodeName  = 'byte_offset' then
          xml_value[NodeNo].byte_offset :=  strtoint(Text)
       else if NodeName  = 'what' then
          xml_value[NodeNo].what :=  Text
       //以下是补丁
       else if  NodeName  = 'value' then
       begin

         //1，匹配"NUM_DISK_SECTORS-(\d+)"
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
           Exit;  //提前退出函数
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
             Exit;  //提前退出函数
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
//这个函数将全部的带有  Num_Disk_SECTORS 的项进行处理
//无论 磁盘大小，都统一处理，后面再针对磁盘大小进一步处理
//处理步骤多一点，但是 简化了流程，容易理解
function TXMLFile.HandleNum_Disk_SECTORS_String(field: string): Int64;
var
  reg: TPerlRegEx;
  Max_disk_in_sec : Int64; //这是一个巨大的数字
begin
  Max_disk_in_sec := EMMCBLD_MAX_DISK_SIZE_IN_BYTES div SECTOR_SIZE;

  //1，匹配"NUM_DISK_SECTORS-(\d+)"
  reg := TPerlRegEx.Create();
  reg.RegEx   := 'NUM_DISK_SECTORS-(\d+)';
  reg.Subject := field;
   if reg.Match then
   begin
     Result := Max_disk_in_sec + strtoint64(reg.Groups[1]);
     reg.Free;
     Exit;  //提前退出函数
   end
   else
     reg.Free;

  //2, 匹配 NUM_DISK_SECTORS 情形
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

  //3, 剩下的就是普通数字
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

      //以下是 补丁专用
      Append('  xml_function: ' + xml_function);
      Append('  value: ' + IntToStr(value));
      Append('  arg0: ' + IntToStr(arg0));
      Append('  arg1: ' + IntToStr(arg1));


    {
       //以下补丁专用
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
  s := '----- 以下显示xml_sorted.xml_value -----------';
  Show_xml_value(Memo,xml_value, s);
end;

procedure TXMLFile.Show_xml_sorted; //xml_sorted内的值，直接显示数组，这个可以访问的
var s: string;
begin
  //xml_sorted.xml_value_sorted;
  s := '----- 显示xml_sorted.xml_value_sorted-----------';
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
  //SetLength(xml_value_sorted,0);  //释放空间
  xml_value_sorted := nil;    //释放空间
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
  //分配一个数据空间
  len :=  Length(xml_value_sorted)+1;
  SetLength(xml_value_sorted , len);

  //拷贝到最后一个空间
  copy_xml(Value, xml_value_sorted[len-1]);   //拷贝值到新的空间
  //xml_value_sorted[i-1] := Value;           //另外一种方式，直接赋值

  pNewRec := @xml_value_sorted[len-1];
  Result := Add(pNewRec);                   //新节点加到 列表中
end;


procedure TStartAddressList.copyfrom(source: array of TMyAddrRec);
var i: Integer;
begin
  for i := 0 to Length(source) - 1 do
    Add(source[i]);
end;

procedure TStartAddressList.copyfrom_filter(source: array of TMyAddrRec); //过滤后拷贝
var i: Integer;
begin
  //剔除 空文件名
  //剔除文件长度为零的
  //剔除 起始扇区为负数的
  //实际文件长度 大于分配的长度的，警告！
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
// 将 AddrArray 中的整数从小到大排序，输出 AddrArray

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

    //找到一个合法的记录，增加到 Addr_sorted 准备排序
    len_dest :=  Length(Addr_sorted)+1;
    SetLength(Addr_sorted, len_dest);
    
    Addr_sorted[len_dest-1] := source[i].start_sector;  //根据起始扇区排序
  end;
end;

//source 排序后结果送 xml_value_sorted
procedure TSortAddr.Sort(const source: array of TMyAddrRec);
var
  i,j: Integer;

//返回地址所在记录的索引号  
function FindAddr(Addr: Int64; const source: array of TMyAddrRec): Integer;
var i: integer;
begin
  Result := -1; //未找到
  for i := 0 to Length(source)-1 do
  begin
    if Length(source[i].filename) <= 0 then   Continue;
    if source[i].start_sector < 0 then Continue;
    //if source[i].num_partition_sectors <= 0 then Continue;

    if Addr = source[i].start_sector then
    begin
      Result := i;
      Exit;         //找到一个立即退出，不能有两个地址相同
    end;
  end;
end;

begin
  //1.
  copyfrom(source);

  //2.
  SortByAddr(Addr_sorted);

  //3.
  //设置排序后的记录长度
  SetLength(xml_value_sorted, Length(Addr_sorted));

  for i := 0 to Length(Addr_sorted)-1 do
  begin
    j := FindAddr(Addr_sorted[i], source);    //在源记录中找 指定地址的记录号
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

//排序并且重定位地址列表，
//并且计算最小磁盘大小，如果实际磁盘尺寸小于它就报错！
constructor TSortAddr.create(const source: array of TMyAddrRec; DiskSizeInBytes: Int64);
const msg = '目标芯片空间太小，无法存下现有的文件！';
const Gbytes = int64(1024*1024*1024);
var
  min_size : Single;
  msg_min_size: string;

begin
  create();
  Sort(source);  //排序的结果送 xml_value_sorted
  //这里要加上重定位，依据磁盘DiskSizeInBytes
  if DiskSizeInBytes > 0 then
    ReLocation_StartAddr(xml_value_sorted, DiskSizeInBytes);
    //先重新定位一下，在计算最小磁盘空间，有点多余呀,不过同高通的算法一样了。
    
  FMinDiskSizeInSectors := CalculateMinDiskSizeInSecter;

  min_size := FMinDiskSizeInSectors * SECTOR_SIZE / Gbytes;
  msg_min_size := FloatToStrF(min_size,ffGeneral, 5, 2);

  if FMinDiskSizeInSectors <= DiskSizeInBytes div  SECTOR_SIZE then
    ReLocation_StartAddr(xml_value_sorted, DiskSizeInBytes)
  else
  begin
    msg_min_size := ' 需要的最小尺寸：' + msg_min_size + 'GB!';
    ShowMessage(msg +  msg_min_size);
    raise Exception.Create(msg);
  end;
end;

class procedure TSortAddr.Relocation_StartAddr(var writedAddr: array of TMyAddrRec; DiskSizeInBytes: int64);
var i  :integer;
    Max_disk_in_sec : Int64; //这是一个巨大的数字,最大支持的磁盘大小 64TB
    StartAddr_Reverse : Int64; //从空间底部计算 的扇区起始地址
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
    //writedAddr[i].arg0  := Relocation(writedAddr[i].arg0);高通这个没有处理，没有这一行
  end;
end;


//---------------------------------------------------------
//依据num_partition_sectors参数计算最小磁盘尺寸
//并且定位特殊扇区的起始位置，如gpt_backup扇区
// 这个空间是芯片目标空间的大小
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
  MLog.device_log('开始计算 最小磁盘空间，MinDiskSizeInSectors');
  s := Format('1, 累计普通分区，max(startsec[i]+num_sec[i]),i=0..%d ', [Length(xml_value_sorted)-1]);
  MLog.device_log(s);
  s :=  ' 公式解释：起始扇区号已经排序，后面的起始扇区号越来越大，其实只要获取最后一个分区就可以了，'
      + ' 当然要去掉起始扇区小于等于0, 起始扇区大于EMMCBLD_MAX_DISK_SIZE_IN_SECTOR的特殊分区 。';
  MLog.device_log(s);

  for i := 0 to  Length(xml_value_sorted)-1 do
  begin
    startsec := xml_value_sorted[i].start_sector;
    num_sec  := xml_value_sorted[i].num_partition_sectors;
    if (startsec>0) and (startsec < EMMCBLD_MAX_DISK_SIZE_IN_SECTOR) then
    begin
      MinDiskSizeInSectors := startsec + num_sec;
      //起始扇区号已经排序，后面的起始扇区号越来越大

      MLog.PrintMinDiskSizeInSecter(i, startsec, num_sec, MinDiskSizeInSectors);
    end;
  end;

  //# second time is for NUM_DISK_SECTORS-33 type of scenarios, since they will currently have
  //# my made up value of EMMCBLD_MAX_DISK_SIZE_IN_BYTES+start_sector
  //# 令人费解的EMMCBLD_MAX_DISK_SIZE_IN_BYTES+start_sector 是程序作者自定义的，有特殊含义

  s := Format('2, 累计特殊分区，max(startsec[i]+num_sec[i]), i=0..%d', [Length(xml_value_sorted)-1]);
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

  MLog.device_log('结束 最小磁盘空间计算，MinDiskSizeInSectors');
  MLog.PrintSpaceLine;

  Result :=  MinDiskSizeInSectors;
end;

end.
