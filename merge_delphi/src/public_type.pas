unit public_type;

interface


type
  uint32 = Cardinal;            //4�ֽ�32����
  
type 
     //TSomeBits = int64;

     TByteDynArray  = array of Byte;
     TpByteDynArray = ^TByteDynArray;
  
type
  //�������û�����Ĳ���
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
     label_str : string;     //�������账��

     filename  : string;
     file_sector_offset    : uint32;

     //ע�⣺��ʼ�����п��ܱ�EMMCBLD_MAX_DISK_SIZE_IN_BYTES����
     // ������int64
     start_sector          : int64;
     num_partition_sectors : uint32;
     SECTOR_SIZE_IN_BYTES  : uint32;

     physical_partition_number : uint32;  //must be zero, or error!
     start_byte_hex: uint32;  //no used
     sparse: boolean;         //no used
     size_in_KB : Single;     //no used

     //���²���ר��
     what : string;
     xml_function : string;   //CRC32
     value        : Int64;    //������ֵ������CRC32��ֵ
     arg0         : Int64;   //start section
     arg1         : Int64;   //length
     size_in_bytes: Int64;   //���ܵ�ֵ��1��2��4,8�ֽڡ����µ�Ŀ���ֽ�����
                              //����value�е��ֽ��������8���ֽ�
     byte_offset  : Int64;   //Ŀ���ַ�������� ��ƫ��ֵ(�ֽڼ����)��
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
