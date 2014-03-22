#　PowershellでRedmineを操作するためのスクリプトです。

function LoadConfig
{
    
    $xml = [xml](Get-Content .\config.xml)

    $apiKey = $xml.config.apiKey
    $rmUrl = $xml.config.rmUrl
    $rmAssign = $xml.config.rmAssign

    $apiKey,$rmUrl,$rmAssign
}

function ShowIssues
{
    # 設定を取得する
    $config = LoadConfig
    $apiKey = $config[0]
    $rmUrl = $config[1]
    $rmAssign = $config[2]
       
    # アクセスするURLを定義する。
    $request = "$rmUrl/issues.json?key=$apiKey&?assigned_to_id=$rmAssign&limit=100"

    # redmineへアクセスし、JSONを取得する。
    $oXMLHTTP = new-object -com "MSXML2.XMLHTTP.3.0"
    $oXMLHTTP.open("GET","$request","False")
    $oXMLHTTP.send()
    $response = $oXMLHTTP.responseText

    # jsonをパースする。
    Add-Type -AssemblyName System.Web.Extensions
    $serializer=new-object System.Web.Script.Serialization.JavaScriptSerializer
    $obj=$serializer.DeserializeObject($response)

    $i = $obj["issues"].count -1
    while ( $i -ge 0)
    {
        $id = $obj["issues"]["$i"]["id"]    
        $issue = $obj["issues"]["$i"]["subject"]
        $status = $obj["issues"]["$i"]["status"]["name"]
        $project = $obj["issues"]["$i"]["project"]["name"]
        Write-Output "$id `t $project `t $status `t $issue "
        $i = $i - 1 
    }
}

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

    $id = $obj["issue"]["id"]    
    $issue = $obj["issue"]["subject"]
    $status = $obj["issue"]["status"]["name"]
    $project = $obj["issue"]["project"]["name"]
    Write-Output "----------------------------------`n Issue `n----------------------------------"
    Write-Output "$id `t $project `t $status `t $issue "

    $i = 0
    Write-Output "----------------------------------`n Detail `n----------------------------------"
    while ( $i -lt $obj["issue"]["journals"].count)
    { 
        $created_on = $obj["issue"]["journals"][$i]["created_on"]
        $name = $obj["issue"]["journals"][$i]["user"]["name"]
        $notes = $obj["issue"]["journals"][$i]["notes"]
        
        Write-Output "$created_on `t $name `t $notes"
        $i++
    }
}

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

function CheckStatus
{
    # 設定を取得する
    $config = LoadConfig
    $apiKey = $config[0]
    $rmUrl = $config[1]

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

    $i = 0
    while ( $i -lt $obj["issue_statuses"].count)
    { 
        $id = $obj["issue_statuses"][$i]["id"]
        $name = $obj["issue_statuses"][$i]["name"]
        
        Write-Output "$id `t $name"
        $i++
    }
}

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

# メイン処理

switch ( $args[0] ){
    # .\rm_cli.ps1 show 
    "show"{ 
        # .\rm_cli.ps1 show [hogehoge]
        switch ( $args[1] ) {
            # .\rm_cli.ps1 show id [hogehoge]
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
            # .\rm_cli.ps1 show
            default {
                ShowIssues
            }
        }
    }
    # .\rm_cli.ps1 update id notes
    "update"{
        UpdateIssue $args[1] $args[2]
    }
    "check"{
        CheckStatus
    }
    "change"{
        switch ( $args[1] ) {
            # .\rm_cli.ps1 change id [hogehoge]
            "id"{
                try{
                    if (( $args[2] -ne $null ) -and ( $args[3] -ne $null )){ 
                        ChangeStatus $args[2] $args[3]
                    }else{
                        Write-Output "ステータスを入力してください。"   
                    } 
                } catch {
                        Write-Output "エラーです。"
                }
            }
            # .\rm_cli.ps1 change
            default {
                Write-Output "id [number]を入力してください。。" 
            }
        }
    }
    default{
        Write-Output "オプションを入力してください。"
    }
}