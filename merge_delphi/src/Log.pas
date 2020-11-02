unit Log;

interface
uses
   public_type;

type

  TLog = class(TObject)
  private
    F: Text;            //TextFile 和 Text 是一样的
    FFileName: string;  //= 'd:\MergeLog.txt';
    FBytesPerSector : Int64;
  public
    property LogFileName: string read FFileName write FFileName;
    property BytesPerSector : Int64 read FBytesPerSector write FBytesPerSector;
  public
    constructor Create();  overload; virtual;
    constructor Create(aLogfileName: string);   overload; virtual;

    procedure reset_device_log();
    procedure device_log(msg: string);
    procedure PrintBigWarning(sz: string);
    procedure PrintBigError(sz: string);
    procedure PrintSpaceLine();
    procedure PrintFileSize(filename: string);
  end;

  TMergeLog = class(TLog)
  private
    FisPrintXML: Boolean;  //是否打印xml的输出
  public
    property isPrintXML : Boolean read FisPrintXML write FisPrintXML;

    constructor Create(); overload; override;
    constructor Create(aLogfileName: string);  overload;  override;

    procedure PrintEvnUserParam(Evn: TEvnUserParam); //打印环境及用户输入的参数
    procedure PrintMinDiskSizeInSecter(no: Integer; startsec,num_sec,MinDiskSizeInSectors: int64);
    procedure PrintXMLValue(Value: type_xml);     overload;
    procedure PrintXMLValue(Value: array of type_xml);     overload;
    procedure PrintXMLValue(Value: array of type_xml; msg: string);     overload;
    procedure PrintPatching(msg: string='');
    procedure PrintPrograming(msg: string='');
    procedure PrintBytesHex(ByteArray: array of Byte);
    procedure PrintUintHex(aInt: uint32);
    procedure PrintPatchLog(no:Integer; filename:string; msg: string);


  end;


var  MLog : TMergeLog;
  
implementation
uses Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Menus, StdCtrls, ExtCtrls, ComCtrls;


constructor TLog.Create();
begin
  inherited;
  LogFileName    := 'd:\MergeLog.txt';
  BytesPerSector := 512;
  
end;

constructor TLog.Create(aLogfileName: string);
begin
   Create();
   FFileName := aLogfileName;
end;
procedure TLog.reset_device_log();
var t: TDateTime;
begin
  AssignFile(F,FFileName);
  try
    Rewrite(F);  //会覆盖已存在的文件
    Writeln(F, '【日志输出测试】：开始一个新的日志文件！');
    Writeln(F, '【日志输出测试】：第二行');
    Writeln(F,'');
    t := Now;
    Writeln(F, '日期：' + DateTimetostr(t) );
    Writeln(F,'');
  finally
    CloseFile(F);
  end;
end;

procedure TLog.PrintFileSize(filename: string);
var size : Int64;
begin
  if Length(filename) = 0 then
    device_log('File name is null!');

  size :=  FileSize(filename);
  if Size < 0 then
    device_log(filename + ' File Don''t Exist！')
  else
    device_log('Found ' + filename + ', Filesize is ' + IntToStr(size) + ' bytes');

end;


procedure TLog.PrintSpaceLine();
begin
    AssignFile(F,FFileName);
  try
    Append(F);          //打开准备追加
    Writeln(F,'');
  finally
    CloseFile(F);
  end;
end;

procedure TLog.device_log(msg: string);
var t: TDateTime;
begin
  AssignFile(F,FFileName);
  try
    Append(F);          //打开准备追加
    t := Now;
    Writeln(F,  timetostr(t) + ' ' + msg);
  finally
    CloseFile(F);
  end;
end;

procedure TLog.PrintBigWarning(sz: string);
begin
    device_log('  ');
    device_log('  ');
    device_log('\t                          _             ');
    device_log('\t                         (_)            ');
    device_log('\t__      ____ _ _ __ _ __  _ _ __   __ _ ');
    device_log('\t\\ \\ /\\ / / _` | ''__| ''_ \\| | ''_ \\ / _` |');
    device_log('\t \\ V  V / (_| | |  | | | | | | | | (_| |') ;
    device_log('\t  \\_/\\_/ \\__,_|_|  |_| |_|_|_| |_|\\__, |');
    device_log('\t                                   __/ |');
    device_log('\t                                  |___/ \n');

    if Length(sz)>0 then
      device_log(sz);

end;

procedure TLog.PrintBigError(sz: string);
var errmsg : string;
begin
    device_log('  ');
    device_log('  ');
    device_log('\t _________________ ___________ ');
    device_log('\t|  ___| ___ \\ ___ \\  _  | ___ \\');
    device_log('\t| |__ | |_/ / |_/ / | | | |_/ /');
    device_log('\t|  __||    /|    /| | | |    / ');
    device_log('\t| |___| |\\ \\| |\\ \\\\ \\_/ / |\\ \\ ');
    device_log('\t\\____/\\_| \\_\\_| \\_|\\___/\\_| \\_|\n');
    device_log('\nERROR - ERROR - ERROR - ERROR - ERROR\n');
    
    if Length(sz)>0 then
    begin
      device_log(sz);
      errmsg := 'MergeUtility failed - Log is ' + FFileName;
      device_log(errmsg);
      raise Exception.Create(errmsg);
    end;

    //application.Terminate;


end;

//======================================================================
//                   TMergeLog
//======================================================================

constructor TMergeLog.Create();
begin
  inherited;
  isPrintXML := False;
end;

constructor TMergeLog.Create(aLogfileName: string);
begin
  inherited;
  isPrintXML := False;
end;


procedure TMergeLog.PrintEvnUserParam(Evn: TEvnUserParam);
begin
    PrintSpaceLine();
    device_log('环境参数以及用户输入的参数：');
    device_log('程序名：' + Evn.EXEName);
    device_log('工作路径 WorkPath：' + Evn.WorkPath);
    device_log('补丁配置文件: '+ Evn.patchxml);
    device_log('原始配置文件: '+ Evn.inputxml);
    device_log('输出映像文件：'+ Evn.outputbin);
    device_log('映像文件大小：' + inttostr(Evn.ChipSizeInBytes)   + ' Bytes');
    device_log('映像文件大小：' + inttostr(Evn.ChipSizeInSectors) + ' Sectors');
    PrintSpaceLine();

    device_log('Looking for ' + Evn.inputxml);
    PrintFileSize(Evn.inputxml);

    device_log('Looking for ' + Evn.patchxml);
    PrintFileSize(Evn.patchxml);


end;

procedure TMergeLog.PrintMinDiskSizeInSecter(no: Integer; startsec, num_sec, MinDiskSizeInSectors: int64);
var s: string;
    MinDiskSizeInM : Single;
begin
 
  MinDiskSizeInM := MinDiskSizeInSectors * BytesPerSector / (1024 * 1024);

  s :=  Format('(%.3d) StartSector:%8d,  SectorNum:%8d,', [no, startsec,num_sec])
      + Format('    MinDiskSizeInSectors:%8d,  MinDiskSizeInM:%8.2fM', [MinDiskSizeInSectors,MinDiskSizeInM]);
  device_log(s);
end;

procedure TMergeLog.PrintXMLValue(Value: type_xml);
begin
   if not isPrintXML then exit;
   
   with Value do
   begin
      device_log('  ');
      device_log('  start_sector: ' + IntToStr(start_sector));
      device_log('  file_sector_offset: ' + IntToStr(file_sector_offset));
      device_log('  num_partition_sectors: ' + IntToStr(num_partition_sectors));
      device_log('  SECTOR_SIZE_IN_BYTES:  ' + IntToStr(SECTOR_SIZE_IN_BYTES));
      device_log('  physical_partition_number: ' + IntToStr(physical_partition_number));
      device_log('  start_byte_hex: ' + IntToStr(start_byte_hex));
      device_log('  label: ' + label_str);
      device_log('  filename: ' + filename);

      //以下是 补丁专用
      device_log('  xml_function: ' + xml_function);  //CRC32
      device_log('  value: ' + IntToStr(value));      //CRC32的值
      device_log('  arg0: ' + IntToStr(arg0));       //start section
      device_log('  arg1: ' + IntToStr(arg1));       //length

    end;

end;

procedure TMergeLog.PrintXMLValue(Value: array of type_xml);
var i : integer;
begin
  if not isPrintXML then exit;
  
  for i := 0 to Length(Value)-1 do
    PrintXMLValue(Value[i]);
end;

procedure TMergeLog.PrintXMLValue(Value: array of type_xml; msg: string);
begin
  if not isPrintXML then exit;

  PrintSpaceLine();
  device_log('--------------------XML解析值输出开始------------------------------');
  device_log(msg);
  PrintXMLValue(Value);
  device_log('--------------------XML输出结束------------------------------------');
end;

procedure TMergeLog.PrintPatching(msg: string='');
begin
 PrintSpaceLine;
 device_log('	             _        _     _              ');
 device_log('	            | |      | |   (_)             ');
 device_log('	 _ __   __ _| |_  ___| |__  _ _ __   __ _  ');
 device_log('	| ''_ \ / _` | __|/ __| ''_ \| | ''_ \ / _` | ');
 device_log('	| |_) | (_| | |_| (__| | | | | | | | (_| | ');
 device_log('	| .__/ \__,_|\__|\___|_| |_|_|_| |_|\__, | ');
 device_log('	| |                                  __/ | ');
 device_log('	|_|                                 |___/  ');

 PrintSpaceLine;
 device_log( msg );
  
end;

procedure TMergeLog.PrintPrograming(msg: string = '');
begin
  PrintSpaceLine;
	device_log('                                                     _              ');
	device_log('                                                    (_)             ');
	device_log(' _ __  _ __ ___   __ _ _ __ __ _ _ __ ___  _ __ ___  _ _ __   __ _  ');
	device_log('| ''_ \| ''__/ _ \ / _` | ''__/ _` | ''_ ` _ \| ''_ ` _ \| | ''_ \ / _` | ');
	device_log('| |_) | | | (_) | (_| | | | (_| | | | | | | | | | | | | | | | (_| | ');
	device_log('| .__/|_|  \___/ \__, |_|  \__,_|_| |_| |_|_| |_| |_|_|_| |_|\__, | ');
	device_log('| |               __/ |                                       __/ | ');
	device_log('|_|              |___/                                       |___/  ');
  PrintSpaceLine;

  device_log(msg);

end;

procedure TMergeLog.PrintBytesHex(ByteArray: array of Byte);
var s: string;
    i : Integer;
begin
  for i := 0 to Length(ByteArray) - 1  do
    s := s + '$'+IntToHex(ByteArray[i], 2)+' ';
    
  device_log(s);
end;

procedure TMergeLog.PrintPatchLog(no:Integer; filename:string; msg: string);
var s: string;
begin
  s := '  (' + inttostr(no)+ '), 文件名：'+ filename + ', '+ msg;
  device_log( s );
  PrintSpaceLine;

end;

procedure TMergeLog.PrintUintHex(aInt: uint32);
var
   byte4 :  array [0..3] of byte;
begin
  Move(aInt,byte4,4);
  PrintBytesHex(byte4);
end;  

end.
