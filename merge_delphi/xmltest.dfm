object Form_xml_test: TForm_xml_test
  Left = 791
  Top = 257
  Width = 964
  Height = 637
  Caption = 'xml'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Memo1: TMemo
    Left = 32
    Top = 120
    Width = 385
    Height = 457
    Lines.Strings = (
      'Memo1')
    ScrollBars = ssBoth
    TabOrder = 0
  end
  object Edit1: TEdit
    Left = 32
    Top = 40
    Width = 217
    Height = 21
    TabOrder = 1
  end
  object Button1: TButton
    Left = 312
    Top = 40
    Width = 75
    Height = 25
    Caption = #35299#26512#25490#24207
    TabOrder = 2
    OnClick = Button1Click
  end
  object Edit2: TEdit
    Left = 32
    Top = 80
    Width = 305
    Height = 21
    TabOrder = 3
    Text = 'Edit2'
  end
  object Memo2: TMemo
    Left = 448
    Top = 120
    Width = 449
    Height = 449
    Lines.Strings = (
      'Memo2')
    ScrollBars = ssBoth
    TabOrder = 4
  end
  object btn_open2: TButton
    Left = 400
    Top = 40
    Width = 75
    Height = 25
    Caption = #35299#26512
    TabOrder = 5
    OnClick = btn_open2Click
  end
  object btn_reg: TButton
    Left = 688
    Top = 40
    Width = 97
    Height = 25
    Caption = #27491#21017#34920#36798#24335
    TabOrder = 6
    OnClick = btn_regClick
  end
  object btn_sorted: TButton
    Left = 800
    Top = 64
    Width = 75
    Height = 25
    Caption = 'xml'#25490#24207
    TabOrder = 7
    OnClick = btn_sortedClick
  end
  object btn_sort2: TButton
    Left = 800
    Top = 32
    Width = 137
    Height = 25
    Caption = #25490#24207#27979#35797'2'
    TabOrder = 8
    OnClick = btn_sort2Click
  end
  object OpenDialog1: TOpenDialog
    Filter = '*.xml|*.xml'
    FilterIndex = 0
    Left = 272
    Top = 40
  end
  object XMLDocument1: TXMLDocument
    Left = 560
    Top = 24
    DOMVendorDesc = 'MSXML'
  end
  object XMLDocument2: TXMLDocument
    Left = 624
    Top = 32
    DOMVendorDesc = 'MSXML'
  end
end
