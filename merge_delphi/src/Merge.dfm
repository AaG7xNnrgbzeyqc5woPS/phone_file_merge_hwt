object Form_Main: TForm_Main
  Left = 521
  Top = 237
  BorderStyle = bsDialog
  Caption = 'Form_Main'
  ClientHeight = 568
  ClientWidth = 639
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Label1: TLabel
    Left = 64
    Top = 32
    Width = 66
    Height = 13
    Caption = 'Address(HEX)'
  end
  object Label2: TLabel
    Left = 288
    Top = 32
    Width = 53
    Height = 13
    Caption = 'File Name :'
  end
  object Label3: TLabel
    Left = 184
    Top = 32
    Width = 22
    Height = 13
    Caption = 'Area'
  end
  object btnMerge: TButton
    Left = 264
    Top = 520
    Width = 75
    Height = 25
    Caption = 'Merge'
    TabOrder = 0
    OnClick = btnMergeClick
  end
  object Button1: TButton
    Left = 64
    Top = 520
    Width = 75
    Height = 25
    Caption = 'Add'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 160
    Top = 520
    Width = 75
    Height = 25
    Caption = 'Reset'
    TabOrder = 2
    OnClick = Button2Click
  end
  object btnMergeclass: TButton
    Left = 392
    Top = 520
    Width = 75
    Height = 25
    Caption = 'EasyMerge'
    TabOrder = 3
    OnClick = btnMergeclassClick
  end
  object Button3: TButton
    Left = 392
    Top = 472
    Width = 75
    Height = 25
    Caption = 'xml'
    TabOrder = 4
    OnClick = Button3Click
  end
  object btn_gaotong: TButton
    Left = 496
    Top = 520
    Width = 75
    Height = 25
    Caption = #39640#36890
    TabOrder = 5
    OnClick = btn_gaotongClick
  end
  object OpenDialog1: TOpenDialog
    Left = 24
    Top = 320
  end
  object SaveDialog1: TSaveDialog
    Left = 24
    Top = 376
  end
end
