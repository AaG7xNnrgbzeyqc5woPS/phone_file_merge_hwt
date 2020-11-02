unit Unit_FileCheck;

interface

uses
  Windows,messages, SysUtils, Classes, DB, DBTables, ADODB, ExtCtrls,Dialogs;

const
  MAX_PARTITION     = 8;      // mean is partition type maxvalue. see PAR_NAME

var
 
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

type
  BlockRec = packed record
    PartID: LongWord;         // partition ID,分区类型 {0..7}
    StartAddr: LongWord;      // Sector unit
    SizebySector: LongWord;   // Sector unit
  end;



type
  Int32  = Integer;
  UInt32 = cardinal;   //4字节32比特无符号整数，cardinal = 0 .. 4*2^32

  //拷贝进度指示，count,当前拷贝的字节计数，totalSize需要拷贝的总字节数
  TCopyDataEvent = procedure (count, totalSize: Int64) of object;
  TCopyFileEvent = procedure (FileCount, totalFileCount: Int64) of object; //拷贝的总文件计数

  TFileCheck = class(TObject)
  private
    FSectorSize : Uint32; //= 512;

    FFileName      : string;
    Ffile_sector_offset : Int64; //文件扇区偏移，在这个偏移之前的数据不写到目标地址去

    FFileStartAddr : Int64;     //此文件在目标文件中的定位，以扇区位单位
    FPartitionType : UInt32;     // {0..7}

  private
    FisFileExists: Boolean;
    FSizebyByte  : UInt32;
    FSizebySector: UInt32;     //每个扇区512字节
    FSizeRemainSector :UInt32; //每个块最后的扇区剩余字节数目
    FSizeFillZero : UInt32;    //最后扇区需要填零的字节数
    
  public
    property isFileExists: Boolean read FisFileExists;     //文件存在否？
    property SizebyByte:UInt32  read FSizebyByte;             //按字节计算的文件长度
    property SizebySector:UInt32  read FSizebySector;         //按扇区计算的文件长度
    property SizeRemainSector:UInt32  read FSizeRemainSector; //最后不足一个扇区的剩余数据长度
    property SizeFillZero:UInt32  read FSizeFillZero;         //补齐一个扇区需要填充的数据长度
    property SectorSize: UInt32 read FSectorSize;

  //文件长度不是512字节的整数的，最后一个扇区剩下的字节填零
  ////计算保存文件所需要的扇区，最后一个扇区如果填不满，用零填充
  public


    constructor Create(aFileName :string; aFileStartAddr: Int64; aPartitionType: UInt32 );
    function    CheckFile: Boolean;

    property  FileName : string  read FFileName;
    property  File_sector_offset: Int64 read FFile_sector_offset;
    property  StartAddress: Int64 read FFileStartAddr;
    property  PartitionType : UInt32 read FPartitionType;

  end;

  TMergeFile = class(TObject)
  private
    FSectorSize : UInt32;
    FCounter : UInt32;  //Block总个数

    FoutFileName : string;
    outfs : TFileStream;   //输出文件流

    FOnCopyDataEvent : TCopyDataEvent; //拷贝数据 每 10M 发生一次
    FCopyFileEvent   : TCopyFileEvent;

    procedure OutFileHead;
    procedure OutIndex;
//    procedure OutData;
    procedure OutData_Slice(); overload;
    procedure OutData_slice(FileIndex: integer); overload; //分割成10M一块写入
    function  OutData_Slice(Source: TStream; Dest: TFileStream; Count: Int64): Int64; overload;

  public
    FInputFile : array of TFileCheck;

    constructor Create(aOutFilename: string; BlockCount: UInt32);
    procedure DoMerge; virtual;

   // procedure   DoMergeThread;
    destructor destroy; override;
    property SectorSize : UInt32 read FSectorSize;
    property Counter: UInt32  read FCounter write FCounter;
    property OnCopyDataEvent : TCopyDataEvent read FOnCopyDataEvent write FOnCopyDataEvent;
    property OnCopyFileEvent : TCopyFileEvent read FCopyFileEvent write FCopyFileEvent;

  public



  end;

  {--------------------------------------
  测试用例：
  关键:
   //1. 指定输出文件out_fs，已经输入文件的个数 Counter
   Merge := TMergeFile.Create(out_fs, Counter);

   //2. 对每个输入文件指定三个参数,文件名，起始扇区，分区id
   Merge.FInputFile[i] := TFileCheck.Create(fname, Addr, partid );

   //3. 合并
   Merge.DoMerge;
  ---------------------------------------


  var Merge : TMergeFile;
  out_fs  : string;
  i       : Integer;
  fname   : string;
  addr    : Int64;
  partid  : UInt32;
begin

  if not CheckEdit then
  begin
    showmessage('输入的参数存在错误');
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
}



implementation

uses
  math,
  unit_DoMergeThread;


Const
  Header : string = 'EMMC Compressed format'#$0A#$0D'Copyright (C) 2016 by Jobs Ju'#$0A#$0D#$1A;

var

    //临时缓冲区
    Buffer : Array of Byte;
    Block : Array of BlockRec;


function TFilecheck.CheckFile: Boolean;
var
  fs: TFileStream;
begin
  Result := false;
  FisFileExists := False;
  
  if Length(FFileName) = 0 then exit;      //文件名长度为零

  FisFileExists := FileExists(FFileName);
  if FisFileExists then
  begin
      fs := TFileStream.Create(FFileName, fmOpenRead);
      FSizebyByte := fs.Size;
      fs.Free;

      FSizebySector     := SizebyByte div SectorSize;
      FSizeRemainSector := SizebyByte mod SectorSize;
      FSizeFillZero     := 0;

      if SizeRemainSector > 0 then
      begin
        Inc(FSizebySector);
        FSizeFillZero  := SectorSize - FSizeRemainSector;
      end;

      Result := True;

  end;
end;

constructor TFilecheck.Create(aFileName :string; aFileStartAddr:Int64; aPartitionType: UInt32 );
begin
  inherited Create();
  FSectorSize := 512;
  FFileName := aFileName;
  FFileStartAddr  := aFileStartAddr;
  FPartitionType  := aPartitionType;
  CheckFile;
end;

constructor TMergeFile.Create(aOutFilename: string; BlockCount: UInt32);
begin
  inherited Create();
  FSectorSize  := 512;

  if ExtractFileExt(aOutFilename) = '' then
        aOutFilename := aOutFilename + '.C.IMG';
  FoutFileName := aOutFilename;

  outfs := TFileStream.Create(FoutFileName, fmCreate);

  Counter :=  BlockCount;
end;

destructor TMergeFile.destroy;
begin
  outfs.Free;
  inherited;
end;


procedure TMergeFile.OutFileHead;
begin
    //1，写文件头
    SetLength(Buffer, $80);                 //缓冲区 $80 = 128字节
    Outfs.Write(Header[1], $80);            //文件头，写签名串，Header :string,  文件头全长 128字节，目前只写签名信息

end;

//2，写索引区
procedure TMergeFile.OutIndex;
var i :Integer;
begin
        //2.0 写索引区总区块数
        Outfs.Write(Counter, SizeOf(Counter));  // 数据块索引区，总块数， Counter Dword ，4字节 。blocks/partitions count

        //2.1 填写索引区数据缓冲区
        SetLength(Block, Counter);     // partition total number(amount)   分区总数
        for i := 0 to Counter - 1 do
        begin
          Block[i].PartID       := FInputFile[i].PartitionType ; //分区类型 {0..7}
          Block[i].SizebySector := FInputFile[i].SizebySector;   //文件占用的扇区数
          Block[i].StartAddr    := FInputFile[i].StartAddress ;  //用扇区号表示
        end;

        //2.2输出整个索引区到文件
        Outfs.Write(Block[0] , Counter * SizeOf(BlockRec));
end;

{
procedure TMergeFile.OutData;
var i     : integer;
    in_fs : TFileStream;  //输入文件流
    len   : Integer;      //需要填充零的字节数
begin
        //3
        for i := 0 to Counter - 1 do
        begin
          in_fs := TFileStream.Create(FInputFile[i].FileName, fmOpenRead);
          Outfs.CopyFrom(in_fs, FInputFile[i].SizebyByte);  //一个一个源文件依次输出到目标文件中
          in_fs.Free;

          //文件长度不是512字节的整数倍的，最后一个扇区剩下的字节填零
          len := FInputFile[i].SizeFillZero;
          if len > 0 then
          begin
            SetLength(Buffer, len);
            FillChar(Buffer[0], len, 0);
            Outfs.Write(Buffer[0], len);
          end;
        end;
end;
}


procedure TMergeFile.OutData_Slice();
var i     : integer;
begin
        for i := 0 to Counter - 1 do
        begin
          OutData_slice(i);
        end;
end;

//处理一个文件输出的全部工作
//1, 打开文件，
//2,seek到起始地址，
//3,输出全部数据，
//4,输出扇区填充数据,
//5关闭输入文件
//6，触发文件输出完毕事件
procedure TMergeFile.OutData_slice(FileIndex: integer);  //分割成10M一块写入
var
    in_fs    : TFileStream;  //输入文件流

    //文件长度不是512字节的整数倍的，最后一个扇区剩下的字节填零
    procedure Fill_Zero_in_last_Sector(File_Index: integer);
    var Len : integer;
    begin
      len := FInputFile[File_Index].SizeFillZero;
      if len > 0 then
      begin
        SetLength(Buffer, len);
        FillChar(Buffer[0], len, 0);
        Outfs.Write(Buffer[0], len);
      end;
    end;
var fname : string;
    f_offset :int64;
begin
   //一个一个源文件依次输出到目标文件中,最大10M，多次输出
  fname := FInputFile[FileIndex].FileName;
  f_offset := FInputFile[FileIndex].File_sector_offset * SectorSize;

  in_fs := TFileStream.Create(fname, fmOpenRead);
  if f_offset > 0 then
    in_fs.Seek(f_offset,soBeginning);
    
  OutData_Slice(in_fs, Outfs, 0);
  in_fs.Free;

  //文件长度不是512字节的整数倍的，最后一个扇区剩下的字节填零
  Fill_Zero_in_last_Sector(FileIndex);

  if Assigned(FCopyFileEvent) then
    FCopyFileEvent(FileIndex + 1, Counter);


    
end;



procedure TMergeFile.DoMerge;
begin
  Self.OutFileHead;
  Self.OutIndex;
  OutData_Slice;
end;

//分块输出一个文件的全部数据
//每输出一个块，触发一次事件，用于进度条

function TMergeFile.OutData_Slice(Source: TStream; Dest: TFileStream; Count: Int64): Int64;
const
  //Max_Slice_Size : Int64 = 10*(1024*1024); //10MBytes  Max_Slice_Size
  Max_Slice_Size : Int64 = 10*1024;          //10KBytes  Max_Slice_Size
var
  Size_Slice, N: Integer;
begin
  // count，拷贝全部的数据
  if Count = 0 then
  begin
    Source.Position := 0;
    Count := Source.Size;
  end;
  Result := Count;

  // Size_Slice,每次拷贝的数据
  Size_Slice := Min(Max_Slice_Size, Count);
  while Count <> 0 do
  begin
    N :=  Min(Size_Slice, Count);
    Dest.CopyFrom(Source,N);
    Dec(Count, N);
    if Assigned(FOnCopyDataEvent) then  FOnCopyDataEvent(Result - Count, Result);
  end;

  if Assigned(FOnCopyDataEvent) then  FOnCopyDataEvent(Result - Count, Result);
  //Exception.Create();
end;

//------------------------------------------------------------------



end.
 