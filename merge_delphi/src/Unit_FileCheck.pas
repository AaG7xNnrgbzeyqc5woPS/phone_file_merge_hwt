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
    PartID: LongWord;         // partition ID,�������� {0..7}
    StartAddr: LongWord;      // Sector unit
    SizebySector: LongWord;   // Sector unit
  end;



type
  Int32  = Integer;
  UInt32 = cardinal;   //4�ֽ�32�����޷���������cardinal = 0 .. 4*2^32

  //��������ָʾ��count,��ǰ�������ֽڼ�����totalSize��Ҫ���������ֽ���
  TCopyDataEvent = procedure (count, totalSize: Int64) of object;
  TCopyFileEvent = procedure (FileCount, totalFileCount: Int64) of object; //���������ļ�����

  TFileCheck = class(TObject)
  private
    FSectorSize : Uint32; //= 512;

    FFileName      : string;
    Ffile_sector_offset : Int64; //�ļ�����ƫ�ƣ������ƫ��֮ǰ�����ݲ�д��Ŀ���ַȥ

    FFileStartAddr : Int64;     //���ļ���Ŀ���ļ��еĶ�λ��������λ��λ
    FPartitionType : UInt32;     // {0..7}

  private
    FisFileExists: Boolean;
    FSizebyByte  : UInt32;
    FSizebySector: UInt32;     //ÿ������512�ֽ�
    FSizeRemainSector :UInt32; //ÿ������������ʣ���ֽ���Ŀ
    FSizeFillZero : UInt32;    //���������Ҫ������ֽ���
    
  public
    property isFileExists: Boolean read FisFileExists;     //�ļ����ڷ�
    property SizebyByte:UInt32  read FSizebyByte;             //���ֽڼ�����ļ�����
    property SizebySector:UInt32  read FSizebySector;         //������������ļ�����
    property SizeRemainSector:UInt32  read FSizeRemainSector; //�����һ��������ʣ�����ݳ���
    property SizeFillZero:UInt32  read FSizeFillZero;         //����һ��������Ҫ�������ݳ���
    property SectorSize: UInt32 read FSectorSize;

  //�ļ����Ȳ���512�ֽڵ������ģ����һ������ʣ�µ��ֽ�����
  ////���㱣���ļ�����Ҫ�����������һ���������������������
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
    FCounter : UInt32;  //Block�ܸ���

    FoutFileName : string;
    outfs : TFileStream;   //����ļ���

    FOnCopyDataEvent : TCopyDataEvent; //�������� ÿ 10M ����һ��
    FCopyFileEvent   : TCopyFileEvent;

    procedure OutFileHead;
    procedure OutIndex;
//    procedure OutData;
    procedure OutData_Slice(); overload;
    procedure OutData_slice(FileIndex: integer); overload; //�ָ��10Mһ��д��
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
  ����������
  �ؼ�:
   //1. ָ������ļ�out_fs���Ѿ������ļ��ĸ��� Counter
   Merge := TMergeFile.Create(out_fs, Counter);

   //2. ��ÿ�������ļ�ָ����������,�ļ�������ʼ����������id
   Merge.FInputFile[i] := TFileCheck.Create(fname, Addr, partid );

   //3. �ϲ�
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
}



implementation

uses
  math,
  unit_DoMergeThread;


Const
  Header : string = 'EMMC Compressed format'#$0A#$0D'Copyright (C) 2016 by Jobs Ju'#$0A#$0D#$1A;

var

    //��ʱ������
    Buffer : Array of Byte;
    Block : Array of BlockRec;


function TFilecheck.CheckFile: Boolean;
var
  fs: TFileStream;
begin
  Result := false;
  FisFileExists := False;
  
  if Length(FFileName) = 0 then exit;      //�ļ�������Ϊ��

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
    //1��д�ļ�ͷ
    SetLength(Buffer, $80);                 //������ $80 = 128�ֽ�
    Outfs.Write(Header[1], $80);            //�ļ�ͷ��дǩ������Header :string,  �ļ�ͷȫ�� 128�ֽڣ�Ŀǰֻдǩ����Ϣ

end;

//2��д������
procedure TMergeFile.OutIndex;
var i :Integer;
begin
        //2.0 д��������������
        Outfs.Write(Counter, SizeOf(Counter));  // ���ݿ����������ܿ����� Counter Dword ��4�ֽ� ��blocks/partitions count

        //2.1 ��д���������ݻ�����
        SetLength(Block, Counter);     // partition total number(amount)   ��������
        for i := 0 to Counter - 1 do
        begin
          Block[i].PartID       := FInputFile[i].PartitionType ; //�������� {0..7}
          Block[i].SizebySector := FInputFile[i].SizebySector;   //�ļ�ռ�õ�������
          Block[i].StartAddr    := FInputFile[i].StartAddress ;  //�������ű�ʾ
        end;

        //2.2����������������ļ�
        Outfs.Write(Block[0] , Counter * SizeOf(BlockRec));
end;

{
procedure TMergeFile.OutData;
var i     : integer;
    in_fs : TFileStream;  //�����ļ���
    len   : Integer;      //��Ҫ�������ֽ���
begin
        //3
        for i := 0 to Counter - 1 do
        begin
          in_fs := TFileStream.Create(FInputFile[i].FileName, fmOpenRead);
          Outfs.CopyFrom(in_fs, FInputFile[i].SizebyByte);  //һ��һ��Դ�ļ����������Ŀ���ļ���
          in_fs.Free;

          //�ļ����Ȳ���512�ֽڵ��������ģ����һ������ʣ�µ��ֽ�����
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

//����һ���ļ������ȫ������
//1, ���ļ���
//2,seek����ʼ��ַ��
//3,���ȫ�����ݣ�
//4,��������������,
//5�ر������ļ�
//6�������ļ��������¼�
procedure TMergeFile.OutData_slice(FileIndex: integer);  //�ָ��10Mһ��д��
var
    in_fs    : TFileStream;  //�����ļ���

    //�ļ����Ȳ���512�ֽڵ��������ģ����һ������ʣ�µ��ֽ�����
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
   //һ��һ��Դ�ļ����������Ŀ���ļ���,���10M��������
  fname := FInputFile[FileIndex].FileName;
  f_offset := FInputFile[FileIndex].File_sector_offset * SectorSize;

  in_fs := TFileStream.Create(fname, fmOpenRead);
  if f_offset > 0 then
    in_fs.Seek(f_offset,soBeginning);
    
  OutData_Slice(in_fs, Outfs, 0);
  in_fs.Free;

  //�ļ����Ȳ���512�ֽڵ��������ģ����һ������ʣ�µ��ֽ�����
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

//�ֿ����һ���ļ���ȫ������
//ÿ���һ���飬����һ���¼������ڽ�����

function TMergeFile.OutData_Slice(Source: TStream; Dest: TFileStream; Count: Int64): Int64;
const
  //Max_Slice_Size : Int64 = 10*(1024*1024); //10MBytes  Max_Slice_Size
  Max_Slice_Size : Int64 = 10*1024;          //10KBytes  Max_Slice_Size
var
  Size_Slice, N: Integer;
begin
  // count������ȫ��������
  if Count = 0 then
  begin
    Source.Position := 0;
    Count := Source.Size;
  end;
  Result := Count;

  // Size_Slice,ÿ�ο���������
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
 