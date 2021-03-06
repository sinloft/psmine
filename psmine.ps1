#　PowershellでRedmineを操作するためのスクリプトです。

# config.xmlからAPIコールに必要な情報を取得する関数。
# 戻り値が異なる用途の場合は、この関数ではなく独自に読み込む事にする。
# 各関数の中で毎回呼び出したほうが良い気がする。

# Load locale/language specific strings
$s = Import-LocalizedData -BaseDirectory (Join-Path -Path $PSScriptRoot -ChildPath Localized)


function LoadConfig
{   
    $xml = [xml](Get-Content -Path $PSScriptRoot'\config.xml')

    $apiKey = $xml.config.apiKey
    $rmUrl = $xml.config.rmUrl
    $rmAssign = $xml.config.rmAssign

    $apiKey,$rmUrl,$rmAssign
}

# チケット一覧を表示する関数
function ShowIssues
{
    # 設定を取得する
    $config = LoadConfig
    $apiKey = $config[0]
    $rmUrl = $config[1]
    $rmAssign = $config[2]
       
    # アクセスするURLを定義する。
    $request = "$rmUrl/issues.json?key=$apiKey&assigned_to_id=$rmAssign&limit=100&status_id=open"

    # redmineへアクセスし、JSONを取得する。
    $oXMLHTTP = new-object -com "MSXML2.XMLHTTP.3.0"
    $oXMLHTTP.open("GET","$request","False")
    $oXMLHTTP.send()
    $response = $oXMLHTTP.responseText

    # jsonをパースする。
    Add-Type -AssemblyName System.Web.Extensions
    $serializer=new-object System.Web.Script.Serialization.JavaScriptSerializer
    $obj=$serializer.DeserializeObject($response)

    $list =@()
    $i = 0
    while ( $i -lt $obj["issues"].count)
    {
        # 表示する内容をカスタムオブジェクトに格納する。
        $hash = New-Object PSObject
        $hash | Add-Member -MemberType "NoteProperty" -Name "ID" -Value $obj["issues"]["$i"]["id"]
        #$hash | Add-Member -MemberType "NoteProperty" -Name "project" -Value $obj["issues"]["$i"]["project"]["name"]
        #$hash | Add-Member -MemberType "NoteProperty" -Name "status" -Value $obj["issues"]["$i"]["status"]["name"]
        $hash | Add-Member -MemberType "NoteProperty" -Name "subject" -Value $obj["issues"]["$i"]["subject"]


        # さらにカスタムオブジェクトに格納する。
        $list += $hash
        $i++
    }
    #　リスト形式でオブジェクトを表示する。
    #$list | Format-List
    $list | Format-Table -AutoSize
}

# チケットの詳細を表示する関数
function ShowDetail($id)
{
    # 設定を取得する
    $config = LoadConfig
    $apiKey = $config[0]
    $rmUrl = $config[1]
    $rmAssign = $config[2]
       
    # アクセスするURLを定義する。
    $request = "$rmUrl/issues/$id.json?key=$apiKey&include=journals"

    # redmineへアクセスし、JSONを取得する。
    $oXMLHTTP = new-object -com "MSXML2.XMLHTTP.3.0"
    $oXMLHTTP.open("GET","$request","False")
    $oXMLHTTP.send()
    $response = $oXMLHTTP.responseText

    # jsonをパースする。
    Add-Type -AssemblyName System.Web.Extensions
    $serializer=new-object System.Web.Script.Serialization.JavaScriptSerializer
    $obj=$serializer.DeserializeObject($response)

    # 表示する内容をカスタムオブジェクトに格納する。
    $summary = New-Object PSObject
    $summary | Add-Member -MemberType "NoteProperty" -Name "ID" -Value $obj["issue"]["id"]
    $summary | Add-Member -MemberType "NoteProperty" -Name "PROJECT" -Value $obj["issue"]["project"]["name"]
    $summary | Add-Member -MemberType "NoteProperty" -Name "TITLE" -Value $obj["issue"]["subject"]
    $summary | Add-Member -MemberType "NoteProperty" -Name "STATUS" -Value $obj["issue"]["status"]["name"]
    $summary | Add-Member -MemberType "NoteProperty" -Name "DESCRIPTION" -Value $obj["issue"]["description"]
    
    # サマリーの表示
    Write-Host -NoNewline ">> Ticket Summary"
    $summary | Format-List 

    # 詳細の表示
    Write-Host ">> Ticket Detail`n"
    $detail =@()
    $i = 0
    while ( $i -lt $obj["issue"]["journals"].count)
    {
        # 表示する内容をカスタムオブジェクトに格納する。
        $hash = New-Object PSObject
        # 時刻の型を変換してからhashに格納する。
        $create_on = [DateTime]$obj["issue"]["journals"][$i]["created_on"]
        $hash | Add-Member -MemberType "NoteProperty" -Name "created_on" -Value $create_on
        $hash | Add-Member -MemberType "NoteProperty" -Name "name" -Value $obj["issue"]["journals"][$i]["user"]["name"]
        $hash | Add-Member -MemberType "NoteProperty" -Name "notes" -Value $obj["issue"]["journals"][$i]["notes"]
        # さらにカスタムオブジェクトに格納する。
        $detail += $hash
        $i++
    }
    $detail | Format-Table -Wrap
}

#　チケットを更新する関数
function UpdateIssue($id, $rmNotes)
{   
    # 設定を取得する
    $config = LoadConfig
    $apiKey = $config[0]
    $rmUrl = $config[1]
    $rmAssign = $config[2]

    # アクセスするURLを定義する。
    $request = "$rmUrl/issues/$id.json?key=$apiKey"

    # redmineに送信するjsonを作成する。
    Add-Type -AssemblyName System.Web.Extensions
    $serializer=new-object System.Web.Script.Serialization.JavaScriptSerializer
    $updateJson = $serializer.Serialize(
    @{
    "issue"=
        @{
            "notes"= "$rmNotes" 
        }
    }
    )

    # redmineへアクセスし、JSONをPUTする。
    $oXMLHTTP = new-object -com "MSXML2.XMLHTTP.3.0"
    $oXMLHTTP.open("PUT","$request","False")
    $oXMLHTTP.setRequestHeader("Content-Type","application/json");
    $oXMLHTTP.send( $updateJson )
    $response = $oXMLHTTP.status
    
    if ($response -eq "200"){
        Write-Output "更新が成功しました"
    }else{
        Write-Output "更新が失敗しました"
    }
}

#　初期設定に必要なステータスのIDを表示する関数
function CheckStatus
{
    # 設定を取得する
    $config = LoadConfig
    $apiKey = $config[0]
    $rmUrl = $config[1]
    
    # ステータスIDの確認処理
    # アクセスするURLを定義する。
    $request = "$rmUrl/issue_statuses.json?key=$apiKey"

    # redmineへアクセスし、JSONを取得する。
    $oXMLHTTP = new-object -com "MSXML2.XMLHTTP.3.0"
    $oXMLHTTP.open("GET","$request","False")
    $oXMLHTTP.send()
    $response = $oXMLHTTP.responseText

    # jsonをパースする。
    Add-Type -AssemblyName System.Web.Extensions
    $serializer=new-object System.Web.Script.Serialization.JavaScriptSerializer
    $obj=$serializer.DeserializeObject($response)

    #　ステータスIDを標準出力する。
    Write-Output ">> Status ID is as below`n"
    $i = 0
    while ( $i -lt $obj["issue_statuses"].count)
    { 
        $id = $obj["issue_statuses"][$i]["id"]
        $name = $obj["issue_statuses"][$i]["name"]
        
        Write-Output "$id `t $name"
        $i++
    }
    
    # プロジェクトIDの確認処理
    # アクセスするURLを定義する。
    $request = "$rmUrl/projects.json?key=$apiKey&limit=100"

    # redmineへアクセスし、JSONを取得する。
    $oXMLHTTP = new-object -com "MSXML2.XMLHTTP.3.0"
    $oXMLHTTP.open("GET","$request","False")
    $oXMLHTTP.send()
    $response = $oXMLHTTP.responseText

    # jsonをパースする。
    Add-Type -AssemblyName System.Web.Extensions
    $serializer=new-object System.Web.Script.Serialization.JavaScriptSerializer
    $obj=$serializer.DeserializeObject($response)

    #　プロジェクトIDを標準出力する。
    Write-Output "`n>> Project ID is as below`n"
    $i = 0
    while ( $i -lt $obj["projects"].count)
    { 
        $id = $obj["projects"][$i]["id"]
        $name = $obj["projects"][$i]["name"]
        
        Write-Output "$id `t $name"
        $i++
    }
    
}

#　チケットのステータス変更に利用する関数。
function ChangeStatus($id,$statusCode)
{   
    # 設定を取得する
    $xml = [xml](Get-Content .\config.xml)

    $apiKey = $xml.config.apiKey
    $rmUrl = $xml.config.rmUrl
    $rmId = $xml.config.rmId

    switch ( $statusCode ){
        "start"{
            $rmStatus = $xml.config.rmId.start
        }
        "close"{
            $rmStatus = $xml.config.rmId.close
        }
    }

    # アクセスするURLを定義する。
    $request = "$rmUrl/issues/$id.json?key=$apiKey"

    # redmineに送信するjsonを作成する。
    Add-Type -AssemblyName System.Web.Extensions
    $serializer=new-object System.Web.Script.Serialization.JavaScriptSerializer
    $updateJson = $serializer.Serialize(
    @{
    "issue"=
        @{
            "status_id"= "$rmStatus" 
        }
    }
    )

    # redmineへアクセスし、JSONをPUTする。
    $oXMLHTTP = new-object -com "MSXML2.XMLHTTP.3.0"
    $oXMLHTTP.open("PUT","$request","False")
    $oXMLHTTP.setRequestHeader("Content-Type","application/json");
    $oXMLHTTP.send( $updateJson )
    $response = $oXMLHTTP.status
    
    if ($response -eq "200"){
        Write-Output "更新が成功しました"
    }else{
        Write-Output "更新が失敗しました"
    }
}

function addIssue($subject,$description)
{   
    # 設定を取得する
    $xml = [xml](Get-Content .\config.xml)

    $apiKey = $xml.config.apiKey
    $rmUrl = $xml.config.rmUrl
    $rmAssign = $xml.config.rmAssign
    $rmProject = $xml.config.rmProject

    # アクセスするURLを定義する。
    $request = "$rmUrl/issues.json?key=$apiKey"

    # redmineに送信するjsonを作成する。
    Add-Type -AssemblyName System.Web.Extensions
    $serializer=new-object System.Web.Script.Serialization.JavaScriptSerializer
    $updateJson = $serializer.Serialize(
    @{
    "issue"=
        @{
            "project_id" = "$rmProject";
            "subject" =  "$subject";
            "description" = "$description";
            "assigned_to_id" = "$rmAssign"
        }
    }
    )

    # redmineへアクセスし、JSONをPOSTする。
    $oXMLHTTP = new-object -com "MSXML2.XMLHTTP.3.0"
    $oXMLHTTP.open("POST","$request","False")
    $oXMLHTTP.setRequestHeader("Content-Type","application/json");
    $oXMLHTTP.send( $updateJson )
    $response = $oXMLHTTP.status
    $responseBody = $oXMLHTTP.responseText
    
    #判定
    if ($response -eq "201"){
        Write-Output "チケットの追加が成功しました"
        
        #結果のjsonをパースする。
        Add-Type -AssemblyName System.Web.Extensions
        $serializer=new-object System.Web.Script.Serialization.JavaScriptSerializer
        $obj=$serializer.DeserializeObject($responseBody)

        #　戻りのjsonからidを抽出して、追加したチケットの詳細を表示する。
        #　メイン処理だと追加されたチケットのidが分からない。戻り値でメイン処理に戻すのではなく、
        #　関数の中でShowDetailを呼び出す。
        $id = $obj["issue"]["id"]
        ShowDetail $id
    }else{
        Write-Output "チケットの追加が失敗しました"
    }
}

# メイン処理
# もう少し綺麗に掛けないものか。。。
switch ( $args[0] ){
    # .\psmine.ps1 show 
    "show"{ 
        # .\psmine.ps1 show [hogehoge]
        switch ( $args[1] ) {
            # .\psmine.ps1 show id [hogehoge]
            "id"{
                try{
                    if ( $args[2] -ne $null ){ 
                        ShowDetail $args[2]
                    }else{
                        Write-Output "IDを入力してください。"   
                    } 
                } catch {
                        Write-Output "エラーです。"
                }
            }
            # .\psmine.ps1 show
            default {
                ShowIssues
            }
        }
    }
    # .\psmine.ps1 update id {number} {notes}
    "update"{
        UpdateIssue $args[2] $args[3]
        ShowDetail $args[2]
    }
    "check"{
        CheckStatus
    }
    "change"{
        switch ( $args[1] ) {
            # .\psmine.ps1 change id [hogehoge]
            "id"{
                try{
                    if (( $args[2] -ne $null ) -and ( $args[3] -ne $null )){ 
                        ChangeStatus $args[2] $args[3]
                        ShowDetail $args[2]
                    }else{
                        Write-Output "ステータスを入力してください。"   
                    } 
                } catch {
                        Write-Output "エラーです。"
                }
            }
            # .\psmine.ps1 change
            default {
                Write-Output "id [number]を入力してください。。" 
            }
        }
    }
    # .\psmine.ps1 add {subject} {description}    
    "add"{
        if (( $args[1] -ne $null ) -and ( $args[2] -ne $null )){
            addIssue $args[1] $args[2]
        } else {
            Write-Output $msgSyntaxError
        }  
    }
    default{
        Write-Output $s.msgHelp
    }
}