#Requires AutoHotkey v2.0
#SingleInstance Force
ListLines 0
SetWorkingDir A_ScriptDir

SetDarkMode(MyGui) {
    if (VerCompare(A_OSVersion, "10.0.17763") >= 0) {
        DWMWA_USE_IMMERSIVE_DARK_MODE := 20
        DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", MyGui.Hwnd, "Int", DWMWA_USE_IMMERSIVE_DARK_MODE, "IntP", 1, "Int", 4)
    }
}

MainGui := Gui("+LastFound", "Auto Rename Pro - Smart Sort")
MainGui.BackColor := "0x1A1A1A"
SetDarkMode(MainGui)
MainGui.SetFont("s10 cWhite", "Segoe UI")

; --- UI ---
MainGui.Add("Text", "w400", "Thư mục mục tiêu (Dán đường dẫn hoặc chọn):")
EditPath := MainGui.Add("Edit", "r1 w320 Background212121 cWhite", "") 
BtnBrowse := MainGui.Add("Button", "x+10 w70", "Chọn")

MainGui.Add("Text", "xm y+10", "Số lượng file:")
TxtCount := MainGui.Add("Text", "x+5 w50 cYellow", "0")

MainGui.Add("Text", "xm y+20", "Đặt tên bắt đầu từ (Ví dụ: C10):")
EditPattern := MainGui.Add("Edit", "xm w400 Background212121 cWhite")

MainGui.Add("Text", "xm y+15", "Xem trước thay đổi:")
TxtPreview := MainGui.Add("Edit", "xm w400 r3 ReadOnly Background333333 cLime", "Đang chờ dữ liệu...")

BtnRename := MainGui.Add("Button", "xm y+20 w400 h40 Default", "BẮT ĐẦU ĐỔI TÊN")

; --- Sự kiện ---
BtnBrowse.OnEvent("Click", SelectFolder)
EditPath.OnEvent("Change", HandlePathChange)
EditPattern.OnEvent("Change", UpdatePreview)
BtnRename.OnEvent("Click", StartRename)

MainGui.Show()

; --- Xử lý logic ---

HandlePathChange(*) {
    if DirExist(EditPath.Value) {
        Files := []
        Loop Files, EditPath.Value "\*.*", "F"
            Files.Push(A_LoopFileName)
        TxtCount.Value := Files.Length
    } else {
        TxtCount.Value := "0"
    }
    UpdatePreview()
}

SelectFolder(*) {
    Selected := DirSelect(EditPath.Value)
    if Selected {
        EditPath.Value := Selected
        HandlePathChange()
    }
}

; Hàm phân tách số và chữ
ParsePattern(InputStr) {
    if RegExMatch(InputStr, "(.*?)(\d+)$", &Match)
        return {Prefix: Match[1], Number: Match[2], Length: StrLen(Match[2])}
    return ""
}

; Hàm sắp xếp tự nhiên (Natural Sort) để C2 đứng trước C10, C218 đứng trước C219
NaturalCompare(a, b) {
    return DllCall("shlwapi\StrCmpLogicalW", "WStr", a, "WStr", b, "Int")
}

UpdatePreview(*) {
    Path := EditPath.Value
    Pattern := EditPattern.Value
    
    if (!DirExist(Path) || Pattern = "" || TxtCount.Value = "0") {
        TxtPreview.Value := "Chưa đủ dữ liệu để xem trước."
        return
    }

    Data := ParsePattern(Pattern)
    if !Data {
        TxtPreview.Value := "Định dạng phải kết thúc bằng số!"
        return
    }

    ; Lấy danh sách file và sắp xếp
    FileList := []
    Loop Files, Path "\*.*", "F"
        FileList.Push(A_LoopFileName)
    
    ; Sắp xếp danh sách file hiện tại theo thứ tự chuẩn Windows
    FileList := SortArray(FileList, NaturalCompare)

    StartNum := Number(Data.Number)
    EndNum := StartNum + FileList.Length - 1
    
    FirstNew := Data.Prefix . Format("{:0" . Data.Length . "d}", StartNum)
    LastNew := Data.Prefix . Format("{:0" . Data.Length . "d}", EndNum)
    
    TxtPreview.Value := "File gốc đầu tiên: " FileList[1] "`n" 
                     . "Đổi thành: " FirstNew " -> " LastNew
}

SortArray(Arr, CompareFunc) {
    for i, item in Arr {
        j := i
        while j > 1 && CompareFunc(Arr[j-1], Arr[j]) > 0 {
            temp := Arr[j]
            Arr[j] := Arr[j-1]
            Arr[j-1] := temp
            j--
        }
    }
    return Arr
}

StartRename(*) {
    Path := EditPath.Value
    Data := ParsePattern(EditPattern.Value)

    if !DirExist(Path) || !Data
        return

    FileList := []
    Loop Files, Path "\*.*", "F"
        FileList.Push(A_LoopFileName)
    
    FileList := SortArray(FileList, NaturalCompare)

    Result := MsgBox("Tiến hành đổi tên " FileList.Length " file theo thứ tự chuẩn?", "Xác nhận", "YesNo")
    if (Result = "No")
        return

    CurrentNum := Number(Data.Number)
    TempFiles := [] 
    
    try {
        ; --- BƯỚC 2.1: ĐỔI TẤT CẢ SANG TÊN TẠM ---
        for FileName in FileList {
            OldPath := Path "\" FileName
            SplitPath OldPath, , , &Ext
            
            ; KIỂM TRA ĐUÔI FILE: Chỉ thêm dấu chấm nếu Ext có dữ liệu
            ExtPart := (Ext != "") ? "." Ext : ""
            
            TempName := "TEMP_RENAME_" . A_TickCount . "_" . A_Index . ExtPart
            TempPath := Path "\" TempName
            
            FileMove OldPath, TempPath, 0 
            
            ; Lưu thêm ExtPart để dùng luôn cho mượt
            TempFiles.Push({TempPath: TempPath, ExtPart: ExtPart})
        }

        ; --- BƯỚC 2.2: ĐỔI TỪ TÊN TẠM SANG TÊN CHÍNH THỨC ---
        for Item in TempFiles {
            ; Sử dụng Item.ExtPart (đã bao gồm dấu chấm nếu có)
            NewName := Data.Prefix . Format("{:0" . Data.Length . "d}", CurrentNum) . Item.ExtPart
            FinalPath := Path "\" NewName
            
            FileMove Item.TempPath, FinalPath, 1 
            CurrentNum++
        }
        
        MsgBox "Thành công đổi tên " FileList.Length " files!", "Thông báo"
        HandlePathChange() 
        
    } catch Error as err {
        MsgBox "Lỗi trong quá trình đổi tên: " err.Message, "Cảnh báo Lỗi"
    }
}