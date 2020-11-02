unit Unit_Patch;

interface
uses
  Windows, SysUtils,Classes, Math, Dialogs,
  Unit_xml;

const test_disk_size = 32*int64(1024*1024*1024);   //32G


type uint32 = dword;
     TSomeBits = int64;

     TpByteDynArray = ^TByteDynArray;
     TByteDynArray = array of Byte;

//function reflect(data: TSomeBits; nBits: integer): TSomeBits;
function CalcCRC32(arr: TByteDynArray; Len: integer): uint32; overload;
function CalcCRC32(stream: TStream; Len: integer): uint32; overload;
procedure PatchToBuffer(patch: type_xml; var buffer: TByteDynArray);
function patch_crc32(opfile: TFileStream; patch: type_xml;  var Readbuf: TByteDynArray): uint32;
procedure patch_other(opfile: TFileStream; patch: type_xml; var Readbuf: TByteDynArray);

procedure PatchNow(opfile: TFileStream; var buf: TByteDynArray; patch: type_xml);

procedure PerformPatching(patch_xml_filename: string; disk_size :Int64 = test_disk_size);

function CRC32(CRC: LongWord; Data: Pointer; DataSize: LongWord): LongWord; assembler;

implementation



var  SECTOR_SIZE: Integer = 512;

function CalcCRC32(stream: TStream; Len: integer): uint32;
var
  arr: TByteDynArray;
  r_num : Integer;
  crc : uint32;
begin
  SetLength(arr,len);
  r_num := stream.Read(arr[0],len);
  if r_num = len then
  begin
    crc := $FFFFFFFF;
    Result := CRC32(crc,@arr[0], len);
  end
  else
    raise Exception.Create('数据流的长度太长');
  
end;

//-------------------------------------------------------

function CalcCRC32(arr: TByteDynArray; Len: integer): uint32; overload;
var
  crc : uint32;
begin
   len := Length(arr);
   crc := $FFFFFFFF;
   Result := CRC32(crc,@arr[0], len);

end;


procedure PerformPatching(patch_xml_filename: string; disk_size :Int64 = test_disk_size);
var
  XMLFile : TXMLFile;
  i,len   : integer;
  opFile  : TFileStream;
  Patch   : type_xml;
  patchfile : string; //需要打补丁的文件名

  Readbuf: TByteDynArray;  //动态数组，保存临时读出来的数据。
begin

  XMLFile    := TXMLFile.Create(patch_xml_filename, disk_size);
  XMLFile.XMLtype := enum_patch; //编程操作，  enum_write enum_patch
  XMLFile.Active  := True;

  Len := Length(XMLFile.patch_value);
  for i:=0 to Len-1 do
  begin
    patchfile := XMLFile.patch_value[i].filename;
    if Length(patchfile) <=0 then Continue;
    if not FileExists(patchfile) then  Continue;
    
    opFile := TFileStream.Create(patchfile, fmOpenReadWrite or fmShareExclusive);
    try
      //with XMLFile.patch_value[i] do
      if XMLFile.patch_value[i].xml_function = 'CRC32' then
      begin
        XMLFile.patch_value[i].value := patch_crc32(opFile, XMLFile.patch_value[i], Readbuf);
      end
      else
      begin
        patch_other(opFile, XMLFile.patch_value[i], Readbuf);
      end;

      //pPatch  := @XMLFile.patch_value[i];
      patch := XMLFile.patch_value[i];
      PatchNow( opFile,Readbuf,patch);

      Readbuf := nil;

    finally
      opFile.Free;
    end;
    
  end;

  XMLFile.Free;

end;

function patch_crc32(opfile: TFileStream; patch: type_xml; var Readbuf: TByteDynArray): uint32;
var PStartSector, PNumSectors, tmp  : Int64;
    StartByte : Int64;
    p : TpByteDynArray;
begin
  //起始地址
  PStartSector := Patch.arg0;
  PNumSectors  := ceil(Patch.arg1 / SECTOR_SIZE); //#向上取整数

  //seek
  if Patch.arg0 > 64 then
  begin
    tmp := (PStartSector-(64-PNumSectors) )*SECTOR_SIZE;
    opfile.Seek(tmp, soBeginning);  //soCurrent
  end
  else
  begin
    opfile.seek(PStartSector*SECTOR_SIZE, soBeginning);
  end;

  //读出指定长度的数据保存到 bytes_read
  if Patch.arg0 > 64 then
  begin
    SetLength(Readbuf,64*SECTOR_SIZE);
    opfile.read(Readbuf[0],64*SECTOR_SIZE);
  end
  else
  begin
    SetLength(Readbuf,Patch.arg1);
    opfile.read(Readbuf[0],Patch.arg1);
  end;

  //计算Bytes中的特定数据的CRC32 结果保存在 Patch['value']
  if Patch.arg0 > 64 then
  begin
    StartByte := (64-PnumSectors)*SECTOR_SIZE;      //再次偏移
    p := @Readbuf[StartByte];
    Patch.value := CalcCRC32(p^,Patch.arg1);
  end
  else
    Patch.value := CalcCRC32(Readbuf,Patch.arg1);
  //以上流程仿照 高通的程序。调试成功后，可以考虑再优化

  result := Patch.value;
end;


procedure Seek(opfile: TFileStream; start_sector: Int64);
begin
  if start_sector > 64  then
    start_sector := start_sector - 63;
  opfile.seek(start_sector * SECTOR_SIZE, soCurrent);
end;

procedure patch_other(opfile: TFileStream; patch: type_xml; var Readbuf: TByteDynArray);
var r_size,read_length : Int64;
begin
  //seek
  Seek(opfile, patch.start_sector);

  //读数据到缓冲区
  read_length := SECTOR_SIZE;
  if Patch.start_sector>64 then
    read_length := 64*SECTOR_SIZE;

  SetLength(Readbuf,read_length);

  // 对于动态数组@Readbuf[0]才是数据真正开始的地方，@Readbuf[0] 和 @Readbuf的值是不同
  r_size := opfile.read(Readbuf[0], read_length);
  if  r_size <> read_length then
    raise Exception.Create('文件尺寸小于需要读的长度！');
end;

 // 对于动态数组@Readbuf[0]才是数据真正开始的地方，@Readbuf[0] 和 @Readbuf的值是不同
  // 可以用下面一段代码测试
  { var s : string;
  s1 := IntToHex(uint32(Pointer(@Readbuf)),4);
  s1 := 'Pointer(@Readbuf) = ' + s1 + ' ';
  s2 := IntToHex(uint32(Pointer(@Readbuf[0])),4);
  s2 := 'Pointer(@Readbuf[0]) = ' + s2 + ' ';
   showmessage( s1 + s2 );
  }


procedure PatchNow(opfile: TFileStream; var buf: TByteDynArray; patch: type_xml);
begin
  //1, 在目标文件opfile中，寻址到将要打补丁地址 
  Seek(opfile, patch.start_sector);

  //2, patch.value 的值 打补丁到  bytes_read 中对应处
  PatchToBuffer(Patch, buf);

  //3，将 bytes_read 写到文件中去
  opfile.write(buf[0],Length(buf));
end;

procedure PatchToBuffer(patch: type_xml; var buffer: TByteDynArray);
var i : integer;
    value : Int64;
    offset :Int64;
begin
  for i:= 0 to Patch.size_in_bytes-1 do
  begin
    offset := Patch.byte_offset + i;
    if patch.start_sector > 64 then
      Inc(offset, 63 * SECTOR_SIZE);

    value := patch.value shr (i*8);  //右移J个字节
    buffer[offset] := value and $FF;
    //最后一个字节送到偏移地址处
  end;
end;
//==========================================================================
//  CRC32算法
//==========================================================================

//CRC-32-IEEE 802.3算法所不同的是多项式常数
//CRC32是0x04C11DB7
//gx	:= $04C11DB7;  // # IEEE 32bit polynomial
//   regs     := $FFFFFFFF;  // # init to all ones
function CRC32(CRC: LongWord; Data: Pointer; DataSize: LongWord): LongWord; assembler;
asm
         AND    EDX,EDX
         JZ     @Exit
         AND    ECX,ECX
         JLE    @Exit
         PUSH   EBX
         PUSH   EDI
         XOR    EBX,EBX
         LEA    EDI,CS:[OFFSET @CRC32]
@Start:  MOV    BL,AL
         SHR    EAX,8
         XOR    BL,[EDX]
         XOR    EAX,[EDI + EBX * 4]
         INC    EDX
         DEC    ECX
         JNZ    @Start
         POP    EDI
         POP    EBX
@Exit:   RET
         DB 0, 0, 0, 0, 0 // Align Table
@CRC32:  DD 000000000h, 077073096h, 0EE0E612Ch, 0990951BAh
         DD 0076DC419h, 0706AF48Fh, 0E963A535h, 09E6495A3h
         DD 00EDB8832h, 079DCB8A4h, 0E0D5E91Eh, 097D2D988h
         DD 009B64C2Bh, 07EB17CBDh, 0E7B82D07h, 090BF1D91h
         DD 01DB71064h, 06AB020F2h, 0F3B97148h, 084BE41DEh
         DD 01ADAD47Dh, 06DDDE4EBh, 0F4D4B551h, 083D385C7h
         DD 0136C9856h, 0646BA8C0h, 0FD62F97Ah, 08A65C9ECh
         DD 014015C4Fh, 063066CD9h, 0FA0F3D63h, 08D080DF5h
         DD 03B6E20C8h, 04C69105Eh, 0D56041E4h, 0A2677172h
         DD 03C03E4D1h, 04B04D447h, 0D20D85FDh, 0A50AB56Bh
         DD 035B5A8FAh, 042B2986Ch, 0DBBBC9D6h, 0ACBCF940h
         DD 032D86CE3h, 045DF5C75h, 0DCD60DCFh, 0ABD13D59h
         DD 026D930ACh, 051DE003Ah, 0C8D75180h, 0BFD06116h
         DD 021B4F4B5h, 056B3C423h, 0CFBA9599h, 0B8BDA50Fh
         DD 02802B89Eh, 05F058808h, 0C60CD9B2h, 0B10BE924h
         DD 02F6F7C87h, 058684C11h, 0C1611DABh, 0B6662D3Dh
         DD 076DC4190h, 001DB7106h, 098D220BCh, 0EFD5102Ah
         DD 071B18589h, 006B6B51Fh, 09FBFE4A5h, 0E8B8D433h
         DD 07807C9A2h, 00F00F934h, 09609A88Eh, 0E10E9818h
         DD 07F6A0DBBh, 0086D3D2Dh, 091646C97h, 0E6635C01h
         DD 06B6B51F4h, 01C6C6162h, 0856530D8h, 0F262004Eh
         DD 06C0695EDh, 01B01A57Bh, 08208F4C1h, 0F50FC457h
         DD 065B0D9C6h, 012B7E950h, 08BBEB8EAh, 0FCB9887Ch
         DD 062DD1DDFh, 015DA2D49h, 08CD37CF3h, 0FBD44C65h
         DD 04DB26158h, 03AB551CEh, 0A3BC0074h, 0D4BB30E2h
         DD 04ADFA541h, 03DD895D7h, 0A4D1C46Dh, 0D3D6F4FBh
         DD 04369E96Ah, 0346ED9FCh, 0AD678846h, 0DA60B8D0h
         DD 044042D73h, 033031DE5h, 0AA0A4C5Fh, 0DD0D7CC9h
         DD 05005713Ch, 0270241AAh, 0BE0B1010h, 0C90C2086h
         DD 05768B525h, 0206F85B3h, 0B966D409h, 0CE61E49Fh
         DD 05EDEF90Eh, 029D9C998h, 0B0D09822h, 0C7D7A8B4h
         DD 059B33D17h, 02EB40D81h, 0B7BD5C3Bh, 0C0BA6CADh
         DD 0EDB88320h, 09ABFB3B6h, 003B6E20Ch, 074B1D29Ah
         DD 0EAD54739h, 09DD277AFh, 004DB2615h, 073DC1683h
         DD 0E3630B12h, 094643B84h, 00D6D6A3Eh, 07A6A5AA8h
         DD 0E40ECF0Bh, 09309FF9Dh, 00A00AE27h, 07D079EB1h
         DD 0F00F9344h, 08708A3D2h, 01E01F268h, 06906C2FEh
         DD 0F762575Dh, 0806567CBh, 0196C3671h, 06E6B06E7h
         DD 0FED41B76h, 089D32BE0h, 010DA7A5Ah, 067DD4ACCh
         DD 0F9B9DF6Fh, 08EBEEFF9h, 017B7BE43h, 060B08ED5h
         DD 0D6D6A3E8h, 0A1D1937Eh, 038D8C2C4h, 04FDFF252h
         DD 0D1BB67F1h, 0A6BC5767h, 03FB506DDh, 048B2364Bh
         DD 0D80D2BDAh, 0AF0A1B4Ch, 036034AF6h, 041047A60h
         DD 0DF60EFC3h, 0A867DF55h, 0316E8EEFh, 04669BE79h
         DD 0CB61B38Ch, 0BC66831Ah, 0256FD2A0h, 05268E236h
         DD 0CC0C7795h, 0BB0B4703h, 0220216B9h, 05505262Fh
         DD 0C5BA3BBEh, 0B2BD0B28h, 02BB45A92h, 05CB36A04h
         DD 0C2D7FFA7h, 0B5D0CF31h, 02CD99E8Bh, 05BDEAE1Dh
         DD 09B64C2B0h, 0EC63F226h, 0756AA39Ch, 0026D930Ah
         DD 09C0906A9h, 0EB0E363Fh, 072076785h, 005005713h
         DD 095BF4A82h, 0E2B87A14h, 07BB12BAEh, 00CB61B38h
         DD 092D28E9Bh, 0E5D5BE0Dh, 07CDCEFB7h, 00BDBDF21h
         DD 086D3D2D4h, 0F1D4E242h, 068DDB3F8h, 01FDA836Eh
         DD 081BE16CDh, 0F6B9265Bh, 06FB077E1h, 018B74777h
         DD 088085AE6h, 0FF0F6A70h, 066063BCAh, 011010B5Ch
         DD 08F659EFFh, 0F862AE69h, 0616BFFD3h, 0166CCF45h
         DD 0A00AE278h, 0D70DD2EEh, 04E048354h, 03903B3C2h
         DD 0A7672661h, 0D06016F7h, 04969474Dh, 03E6E77DBh
         DD 0AED16A4Ah, 0D9D65ADCh, 040DF0B66h, 037D83BF0h
         DD 0A9BCAE53h, 0DEBB9EC5h, 047B2CF7Fh, 030B5FFE9h
         DD 0BDBDF21Ch, 0CABAC28Ah, 053B39330h, 024B4A3A6h
         DD 0BAD03605h, 0CDD70693h, 054DE5729h, 023D967BFh
         DD 0B3667A2Eh, 0C4614AB8h, 05D681B02h, 02A6F2B94h
         DD 0B40BBE37h, 0C30C8EA1h, 05A05DF1Bh, 02D02EF8Dh
         DD 074726F50h, 0736E6F69h, 0706F4320h, 067697279h
         DD 028207468h, 031202963h, 020393939h, 048207962h
         DD 06E656761h, 064655220h, 06E616D64h, 06FBBA36Eh
end;









//-------------------------------------------------------------
//#计算CRC32
//#polynomial 多项式
//iEEE标准算法
//gx	:= $04C11DB7;  // # IEEE 32bit polynomial
//   regs     := $FFFFFFFF;
// 根据高通的算法 ，移植过来的，调试没有通过，有范围检测错误，现在用网上找的模块。
//--------------------------------------------------------------------------------
{
function CalcCRC32(arr: TByteDynArray; Len: integer): uint32;
var
  k,MSB,gx, regs,regsMask,ReflectedRegs,regsMSB : uint32;
  i,j:  Integer;
  DataByte : Byte;

begin
   k  := 8;        //  # length of unit (i.e. byte)
   MSB:= 0;
   gx	:= $04C11DB7;  // # IEEE 32bit polynomial
   regs     := $FFFFFFFF;  // # init to all ones
   regsMask := $FFFFFFFF;  // # ensure only 32 bit answer

   for i:= 0 to Len-1 do     //# Len=5 ; range(Len) --> [0, 1, 2, 3, 4]
   begin
      DataByte := arr[i];
      DataByte := reflect(DataByte, 8);

      for j := 0 to k-1 do
      begin
        MSB := DataByte shr (k-1);  //## get MSB
        MSB := MSB and 1;                //## ensure just 1 bit;

        regsMSB := (regs shr 31) and 1;

        regs := regs shl 1;          //## shift regs for CRC-CCITT

        if (regsMSB xor MSB) > 0 then       //## MSB is a 1
            regs := regs xor gx;    //## XOR with generator poly

        regs := regs and regsMask; //## Mask off excess upper bits

        DataByte := DataByte shl 1;          //## get to next bit
      end;
   end;

   regs          := regs and regsMask; //## Mask off excess upper bits
   ReflectedRegs := reflect(regs,32) xor $FFFFFFFF;

   Result := ReflectedRegs;

end;



   
//-----------------------------------------------------
// 比特位反转，镜像！
// A8h reflected is 15h, i.e. 10101000 <--> 00010101

function reflect(data: TSomeBits; nBits: integer): TSomeBits;
var
  reflection : TSomeBits;
  mask :  TSomeBits;
  bit :integer;
begin
    if SizeOf(TSomeBits) < nBits then
      raise Exception.Create('输入的比特索引大过数据类型的大小！');

    reflection := $00000000;
    for bit := 0 to nBits-1 do
    begin
        if data and $01 = 1 then
        begin              //取数据的最低位，如果为1：
          //mask 是关键，对于8比特数据，第i位和 第7-i位互为镜像
          mask :=  1 shl ((nBits - 1) - bit);
          reflection := reflection or mask;
          data := data shr 1;
        end;
    end;
    result :=    reflection;
end;
}

end.