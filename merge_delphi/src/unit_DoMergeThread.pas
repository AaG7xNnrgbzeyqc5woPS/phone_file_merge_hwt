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

    FOnCopyDataEvent : TCopyDataEvent; //�������� ÿ 10M ����һ��
    FOnCopyFileEvent : TCopyFileEvent;
    FOnMergeCompleted: TOnEvent;      //�ϲ����

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
    property OnMergeCompleted: TOnEvent read FOnMergeCompleted write FOnMergeCompleted;      //�ϲ����
  end;


procedure ExecuteInThread(dosomeThing: TDoSameThing;
                          Evn: TEvnUserParam;
                          DoCopyDataEvent : TCopyDataEvent = nil; //�������� ÿ 10M ����һ��
                          DoCopyFileEvent : TCopyFileEvent = nil;
                          DoMergerCompleted: TOnEvent = nil
                          );

implementation

uses   Main_xml_Merge, Unit_Patch;


procedure ExecuteInThread(dosomeThing: TDoSameThing;
                          Evn: TEvnUserParam;
                          DoCopyDataEvent : TCopyDataEvent = nil; //�������� ÿ 10M ����һ��
                          DoCopyFileEvent : TCopyFileEvent = nil;
                          DoMergerCompleted: TOnEvent = nil
                          );
                          
var myThread: TDOMergeThread;
begin
   //---------------------------------------------
   //�ϲ��ļ�

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
  //�ȴ򲹶�, ���Ҫ�ŵ����߳���
  PerformPatching(patchxml,DiskSizeInBytes);
end;

//execute ���߳����е�ʱ���Զ�ִ�У�����Ҫ����
procedure TDOMergeThread.Execute;
begin
  { Place thread code here }
  FreeOnTerminate := True; {��������߳�ִ����Ϻ��漴�ͷ�}

  //-----------------------------------------------
  //�ȴ򲹶�, ���Ҫ�ŵ����߳���
  //PerformPatching(patchxml,DiskSizeInBytes);

  Synchronize(DoPerformPatching);

  //�ϲ��ļ�
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
//�Ѿ����� ʹ��  Synchronize ���� CopyDataEvent�¼�
//�ؼ���ʹ��ȫ�ֱ������ݲ�����ֻ������취��
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

    MLog.PrintPrograming('��ʼ����XML��');

    Synchronize(DO_LoadParamFromXML);

    if assigned(FOnCopyDataEvent) then MyMerge.OnCopyDataEvent := update_CopyData;
    if assigned(FOnCopyFileEvent) then MyMerge.OnCopyFileEvent := update_CopyFile;

    MLog.PrintPrograming('��ʼ���');
    MyMerge.DoMerge;

    MyMerge.Free;
    MyMerge := nil;
end;

procedure TDOMergeThread.DO_LoadParamFromXML;
begin
  LoadParamFromXML(Finputxml, Foutputbin, FDiskSizeInBytes);
end;

//load param to MyMerge.FInputFile from xml
// 3���������  inputxml, outputbin: string; DiskSizeInBytes :Int64
// �������    MyMerge.FInputFile
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
    // 3���������  inputxml, outputbin: string; DiskSizeInBytes :Int64
    // �������    MyMerge.FInputFile
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
//����� ���߳� �汾
// ����ͨ�� 2016.4.26
// ����
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

    MyMerge.DoMerge;          //ʹ��threadִ���������

    MyMerge.Free;


end;

end.
