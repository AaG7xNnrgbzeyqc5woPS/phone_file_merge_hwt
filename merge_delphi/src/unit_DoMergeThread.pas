unit unit_DoMergeThread;

interface

uses
  Classes, Unit_xml, Unit_FileCheck, public_type, Log;

type
  TDoSameThing  = procedure () of object;
  TOnEvent = procedure (sender : TObject) of object;

  TDOMergeThread = class(TThread)
  private
    { Private declarations }
    FDoSameThing : TDoSameThing;
    myMerge : TMergeFile;

  private
    //FEvn:  TEvnUserParam;
    Fpatchxml: string;
    Finputxml: string;
    Foutputbin: string;

    FDiskSizeInBytes :Int64;

    FOnCopyDataEvent : TCopyDataEvent; //拷贝数据 每 10M 发生一次
    FOnCopyFileEvent : TCopyFileEvent;
    FOnMergeCompleted: TOnEvent;      //合并完成

    procedure Synchronize_DoMergeCompletedEvent;
    procedure Synchronize_CopyDataEvent;
    procedure update_CopyData(count, total : int64);
    procedure Synchronize_CopyFileEvent;
    procedure update_CopyFile(count, total : int64);
    procedure DoPerformPatching();

  protected
    procedure Execute; override;
    procedure Merge();
    procedure DO_LoadParamFromXML;
    procedure LoadParamFromXML(inputxml, outputbin: string; DiskSizeInBytes :Int64);
  public
    constructor Create(CreateSuspended: Boolean);
    property DoSameThing:  TDoSameThing read FDoSameThing write FDoSameThing;

    property patchxml: string read Fpatchxml write Fpatchxml;
    property InputXML : string read Finputxml write Finputxml;
    property OutputImg: string read Foutputbin write Foutputbin;
    property DiskSizeInBytes : int64 read FDiskSizeInBytes write FDiskSizeInBytes;

    property OnCopyDataEvent : TCopyDataEvent read FOnCopyDataEvent write FOnCopyDataEvent;
    property OnCopyFileEvent : TCopyFileEvent read FOnCopyFileEvent write FOnCopyFileEvent;
    property OnMergeCompleted: TOnEvent read FOnMergeCompleted write FOnMergeCompleted;      //合并完成
  end;


procedure ExecuteInThread(dosomeThing: TDoSameThing;
                          Evn: TEvnUserParam;
                          DoCopyDataEvent : TCopyDataEvent = nil; //拷贝数据 每 10M 发生一次
                          DoCopyFileEvent : TCopyFileEvent = nil;
                          DoMergerCompleted: TOnEvent = nil
                          );

implementation

uses   Main_xml_Merge, Unit_Patch;


procedure ExecuteInThread(dosomeThing: TDoSameThing;
                          Evn: TEvnUserParam;
                          DoCopyDataEvent : TCopyDataEvent = nil; //拷贝数据 每 10M 发生一次
                          DoCopyFileEvent : TCopyFileEvent = nil;
                          DoMergerCompleted: TOnEvent = nil
                          );
                          
var myThread: TDOMergeThread;
begin
   //---------------------------------------------
   //合并文件

   myThread :=  TDOMergeThread.Create(True);
   myThread.DoSameThing     := dosomeThing;

   myThread.InputXML  :=  Evn.Inputxml;
   myThread.OutputImg :=  Evn.Outputbin;
   myThread.patchxml  :=  Evn.patchxml;
   myThread.DiskSizeInBytes := Evn.ChipSizeInBytes;
  
   
   myThread.OnCopyDataEvent := DoCopyDataEvent;
   myThread.OnCopyFileEvent := DoCopyFileEvent;
   myThread.OnMergeCompleted := DoMergerCompleted;
   
   myThread.Resume;
 
end;


{ Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);

  and UpdateCaption could look like,

    procedure DOMergeThread.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; }

{ DOMergeThread }

procedure  TDOMergeThread.DoPerformPatching();
begin
   //-----------------------------------------------
  //先打补丁, 这个要放到主线程中
  PerformPatching(patchxml,DiskSizeInBytes);
end;

//execute 在线程运行的时候自动执行，不需要调用
procedure TDOMergeThread.Execute;
begin
  { Place thread code here }
  FreeOnTerminate := True; {这可以让线程执行完毕后随即释放}

  //-----------------------------------------------
  //先打补丁, 这个要放到主线程中
  //PerformPatching(patchxml,DiskSizeInBytes);

  Synchronize(DoPerformPatching);

  //合并文件
  Merge;

  Synchronize(Synchronize_DoMergeCompletedEvent);

  if assigned(FDoSameThing) then
  begin
     FDoSameThing;
  end;
end;

constructor TDOMergeThread.Create(CreateSuspended: Boolean);
begin
  inherited;
  FDoSameThing := nil;
end;

//-----------------------------------------------------------------
//费劲周折 使用  Synchronize 调用 CopyDataEvent事件
//关键是使用全局变量传递参数，只有这个办法了
var CopyData_count, CopyData_total : int64;
procedure TDOMergeThread.update_CopyData(count, total : int64);
begin
     CopyData_count := count;
     CopyData_total := total;
     Synchronize(Synchronize_CopyDataEvent);
end;

procedure TDOMergeThread.Synchronize_CopyDataEvent;
begin
   if assigned(FOnCopyDataEvent) then
     FOnCopyDataEvent(CopyData_count, CopyData_total);
end;


//---------------------------------------------------------------
var  CopyFile_count, CopyFile_total : int64;
procedure TDOMergeThread.update_CopyFile(count, total : int64);
begin
  CopyFile_count := count;
  CopyFile_total := total;
  Synchronize(Synchronize_CopyFileEvent);
end;

procedure TDOMergeThread.Synchronize_CopyFileEvent;
begin
   if assigned(FOnCopyFileEvent) then
     FOnCopyFileEvent(CopyFile_count, CopyFile_total);
end;
//---------------------------------------------------------------

procedure TDOMergeThread.Synchronize_DoMergeCompletedEvent;
begin
  if Assigned(FOnMergeCompleted) then
    FOnMergeCompleted(nil);
end;

//---------------------------------------------------------


procedure TDOMergeThread.Merge();
begin

    MLog.PrintPrograming('开始分析XML！');

    Synchronize(DO_LoadParamFromXML);

    if assigned(FOnCopyDataEvent) then MyMerge.OnCopyDataEvent := update_CopyData;
    if assigned(FOnCopyFileEvent) then MyMerge.OnCopyFileEvent := update_CopyFile;

    MLog.PrintPrograming('开始编程');
    MyMerge.DoMerge;

    MyMerge.Free;
    MyMerge := nil;
end;

procedure TDOMergeThread.DO_LoadParamFromXML;
begin
  LoadParamFromXML(Finputxml, Foutputbin, FDiskSizeInBytes);
end;

//load param to MyMerge.FInputFile from xml
// 3个输入参数  inputxml, outputbin: string; DiskSizeInBytes :Int64
// 输出参数    MyMerge.FInputFile
procedure TDOMergeThread.LoadParamFromXML(inputxml, outputbin: string; DiskSizeInBytes :Int64);
var
  xml     : TXMLFile;
  i       : Integer;
  fname   : string;
  addr    : Int64;
  partid  : UInt32;
  total   : int32;

  tmp : TMyAddrRec;
begin
    // 3个输入参数  inputxml, outputbin: string; DiskSizeInBytes :Int64
    // 输出参数    MyMerge.FInputFile
    XML        := TXMLFile.Create(inputxml, DiskSizeInBytes);
    XML.Active := True;
    total      := Length(XML.xml_Sorted.xml_value_sorted);

    MyMerge := TMergeFile.Create(outputbin, total);
    SetLength(MyMerge.FInputFile, total);

    for i := 0 to total-1 do
    begin
      tmp     := XML.xml_Sorted.xml_value_sorted[i];
      fname   := tmp.filename;
      Addr    := tmp.start_sector;
      partid  := tmp.physical_partition_number;
      MyMerge.FInputFile[i] := TFileCheck.Create(fname, Addr, partid);
    end;
    XML.Free;
end;


//---------------------------------------------------------------------------
//---------------------------------------------------------------------------
//这个是 单线程 版本
// 调试通过 2016.4.26
// 备用
//---------------------------------------------------------------------------
procedure Merge(inputxml: string; outputbin: string; DiskSizeInBytes :Int64);
var
  xml     : TXMLFile;
  myMerge : TMergeFile;

  i       : Integer;
  fname   : string;
  addr    : Int64;
  partid  : UInt32;

  total   : int32;

  tmp : TMyAddrRec;
begin
    XML        := TXMLFile.Create(inputxml, DiskSizeInBytes);
    XML.Active := True;
    total      := Length(XML.xml_Sorted.xml_value_sorted);

    MyMerge := TMergeFile.Create(outputbin, total);
    SetLength(MyMerge.FInputFile, total);

    for i := 0 to total-1 do
    begin
      tmp     := XML.xml_Sorted.xml_value_sorted[i];
      fname   := tmp.filename;
      Addr    := tmp.start_sector;
      partid  := tmp.physical_partition_number;
      MyMerge.FInputFile[i] := TFileCheck.Create(fname, Addr, partid);
    end;
    XML.Free;

   // MyMerge.OnCopyDataEvent := update_dataProcessbar;
    //MyMerge.OnCopyFileEvent := update_fileProcessbar;

    MyMerge.DoMerge;          //使用thread执行这个过程

    MyMerge.Free;


end;

end.
