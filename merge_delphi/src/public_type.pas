unit public_type;

interface


type
  uint32 = Cardinal;            //4字节32比特
  
type 
     //TSomeBits = int64;

     TByteDynArray  = array of Byte;
     TpByteDynArray = ^TByteDynArray;
  
type
  //环境及用户输入的参数
  TEvnUserParam = record
    EXEName : string;
    WorkPath: string;
    BytesPerSector:    Int64;
    ChipSizeInBytes:   Int64;
    ChipSizeInSectors: Int64;

    patchxml: string;
    inputxml: string;
    outputbin: string;

  end;


  type_xml = packed record
     label_str : string;     //程序无需处理

     filename  : string;
     file_sector_offset    : uint32;

     //注意：起始扇区有可能比EMMCBLD_MAX_DISK_SIZE_IN_BYTES还大，
     // 所以用int64
     start_sector          : int64;
     num_partition_sectors : uint32;
     SECTOR_SIZE_IN_BYTES  : uint32;

     physical_partition_number : uint32;  //must be zero, or error!
     start_byte_hex: uint32;  //no used
     sparse: boolean;         //no used
     size_in_KB : Single;     //no used

     //以下补丁专用
     what : string;
     xml_function : string;   //CRC32
     value        : Int64;    //补丁的值，或者CRC32的值
     arg0         : Int64;   //start section
     arg1         : Int64;   //length
     size_in_bytes: Int64;   //可能的值，1，2，4,8字节。更新的目标字节数，
                              //或者value有的字节数，最多8个字节
     byte_offset  : Int64;   //目标地址在扇区内 的偏移值(字节计算的)，
                              //


  end;

  function FileSize(FileName: string ): Int64;

implementation
uses
  SysUtils, Classes;
//  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
//  Dialogs, StdCtrls;

  function FileSize(FileName: string ): Int64;
  var
    fs: TFileStream;
  begin
    Result := -1;
    if (Length(FileName) > 0) and FileExists(FileName) then
    begin
        fs := TFileStream.Create(FileName, fmOpenRead);
        try
          Result := fs.Size;
        finally
          fs.Free;
        end;
    end;
  end;

end.
