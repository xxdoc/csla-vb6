VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "InvoiceItems"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = True
Option Explicit

Private mcolItems As Collection
Private mflgEditing As Boolean

Private Sub Class_Initialize()

  Set mcolItems = New Collection

End Sub

Public Function Item(ByVal Index As Variant) As InvoiceItem
Attribute Item.VB_UserMemId = 0

  Set Item = mcolItems(Index)

End Function

Public Function Count() As Long

    Count = mcolItems.Count

End Function

Public Function NewEnum() As IUnknown
Attribute NewEnum.VB_UserMemId = -4
Attribute NewEnum.VB_MemberFlags = "40"

  Set NewEnum = mcolItems.[_NewEnum]

End Function

Public Sub BeginEdit()

  Dim objInvoiceItem As InvoiceItem
  Dim objTape As InvoiceTape
  Dim objFee As InvoiceFee
  
  If mflgEditing Then Err.Raise 445
  
  For Each objInvoiceItem In mcolItems
    If objInvoiceItem.ItemType = ITEM_FEE Then
      Set objFee = objInvoiceItem
      objFee.ChildBeginEdit

    Else
      Set objTape = objInvoiceItem
      objTape.ChildBeginEdit

    End If
  Next

  mflgEditing = True

End Sub

Public Sub CancelEdit()

  Dim objInvoiceItem As InvoiceItem
  Dim objTape As InvoiceTape
  Dim objFee As InvoiceFee
  Dim lngIndex As Long
  
  If Not mflgEditing Then Err.Raise 445
  
  mflgEditing = False
  For lngIndex = mcolItems.Count To 1 Step -1
    Set objInvoiceItem = mcolItems.Item(lngIndex)
    If objInvoiceItem.ItemType = ITEM_FEE Then
      Set objFee = objInvoiceItem

      With objFee
        If .IsNew Then _
          mcolItems.Remove lngIndex
        .ChildCancelEdit
      End With

    Else
      Set objTape = objInvoiceItem

      With objTape
        .ChildCancelEdit
        If .IsNew Then _
          mcolItems.Remove lngIndex
      End With

    End If

  Next lngIndex

End Sub


Public Sub ApplyEdit(InvoiceID As Long)

  Dim objPersist As InvoiceItemsPersist
  Dim strTapes As String
  Dim strFees As String
  
  If Not mflgEditing Then Err.Raise 445
  
  Set objPersist = CreateObject("VideoServer.InvoiceItemsPersist", PERSIST_SERVER)
  strTapes = objPersist.SaveTapes(InvoiceID, GetTapes)
  strFees = objPersist.SaveFees(GetFees)
  Set objPersist = Nothing
  
  Set mcolItems = Nothing
  Set mcolItems = New Collection
  SetTapes strTapes
  SetFees strFees
  
  mflgEditing = False

End Sub


Public Sub Delete()

  Dim objInvoiceItem As InvoiceItem
  
  If Not mflgEditing Then Err.Raise 445
  ' code to delete the object's data goes here

  For Each objInvoiceItem In mcolItems
    With objInvoiceItem
      .BeginEdit
      .Delete
      .ApplyEdit
    End With

  Next

End Sub

Public Function Add(TapeID As Long) As InvoiceItem

  Dim objInvoiceTape As InvoiceTape
  Dim objTape As Tape

  If Not mflgEditing Then Err.Raise 445

  Set objTape = New Tape
  objTape.Load TapeID
  
  If objTape.CheckedOut Then
    Set objTape = Nothing
    Err.Raise vbObjectError + 1100, _
      "InvoiceItems", "Tape already checked out"
    Exit Function
  End If
  
  Set objInvoiceTape = New InvoiceTape
  objInvoiceTape.Initialize objTape, Me
  If mflgEditing Then objInvoiceTape.ChildBeginEdit
  
  Set Add = objInvoiceTape
  Set objInvoiceTape = Nothing

End Function

Friend Sub AddTape(Child As InvoiceTape)
  
  mcolItems.Add Item:=Child

End Sub

Public Sub Remove(ByVal Index As Variant)

  If Not mflgEditing Then Err.Raise 445

  With mcolItems(Index)
    .BeginEdit
    .Delete
    .ApplyEdit
  End With

End Sub

Friend Sub Load(InvoiceID As Long)

  Dim objPersist As InvoiceItemsPersist
  
  If mflgEditing Then Err.Raise 445
  
  Set objPersist = CreateObject("VideoServer.InvoiceItemsPersist", PERSIST_SERVER)
  SetTapes objPersist.FetchTapes(InvoiceID)
  Set objPersist = Nothing
  
End Sub



Friend Sub LoadFees(CustomerID As Long)

  Dim objPersist As InvoiceItemsPersist
  
  If mflgEditing Then Err.Raise 445
  
  Set objPersist = CreateObject("VideoServer.InvoiceItemsPersist", PERSIST_SERVER)
  SetFees objPersist.FetchFees(CustomerID)
  Set objPersist = Nothing

End Sub

Friend Property Get SubTotal() As Double

  Dim objItem As InvoiceItem
  Dim dblAmount As Double
  
  For Each objItem In mcolItems
    If Not objItem.IsDeleted Then _
      dblAmount = dblAmount + objItem.Total
  Next

  SubTotal = dblAmount

End Property


Private Function GetTapes() As String

  Dim objBuffer As Buffer
  Dim objItem As InvoiceItem
  Dim objTape As InvoiceTape
  
  Set objBuffer = New Buffer
  Set objTape = New InvoiceTape
  objBuffer.Initialize Len(objTape.GetState), 20
  Set objTape = Nothing
  
  For Each objItem In mcolItems
    If objItem.ItemType = ITEM_TAPE Then
      Set objTape = objItem
      objBuffer.Add objTape.GetState
    End If
  Next

  GetTapes = objBuffer.GetState
  Set objBuffer = Nothing

End Function

Private Sub SetTapes(Buffer As String)

  Dim lngIndex As Long
  Dim objTape As InvoiceTape
  Dim objBuffer As Buffer

  Set objBuffer = New Buffer
  objBuffer.SetState Buffer

  For lngIndex = 1 To objBuffer.Count
    Set objTape = New InvoiceTape
    objTape.SetState objBuffer.Item(lngIndex)
    mcolItems.Add Item:=objTape
  Next

End Sub


Private Function GetFees() As String

  Dim objBuffer As Buffer
  Dim objItem As InvoiceItem
  Dim objFee As InvoiceFee
  
  Set objBuffer = New Buffer
  Set objFee = New InvoiceFee
  objBuffer.Initialize Len(objFee.GetState), 20
  Set objFee = Nothing
  
  For Each objItem In mcolItems
    If objItem.ItemType = ITEM_FEE Then
      Set objFee = objItem
      objBuffer.Add objFee.GetState
    End If
  Next

  GetFees = objBuffer.GetState
  Set objBuffer = Nothing

End Function

Private Sub SetFees(Buffer As String)

  Dim lngIndex As Long
  Dim objFee As InvoiceFee
  Dim objBuffer As Buffer

  Set objBuffer = New Buffer
  objBuffer.SetState Buffer

  For lngIndex = 1 To objBuffer.Count
    Set objFee = New InvoiceFee
    objFee.SetState objBuffer.Item(lngIndex)
    mcolItems.Add Item:=objFee
  Next

End Sub



