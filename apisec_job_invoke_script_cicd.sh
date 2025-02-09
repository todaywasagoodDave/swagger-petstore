#!/bin/bash
# Begin
TEMP=$(getopt -n "$0" -a -l "username:,password:,project:,profile:,scanner:,emailReport:,reportType:,tags:" -- -- "$@")

    [ $? -eq 0 ] || exit

    eval set --  "$TEMP"

    while [ $# -gt 0 ]
    do
             case "$1" in
                    --username) FX_USER="$2"; shift;;
                    --password) FX_PWD="$2"; shift;;
                    --project) FX_PROJECT_NAME="$2"; shift;;
                    --profile) JOB_NAME="$2"; shift;;
                    --scanner) REGION="$2"; shift;;
                    --emailReport) FX_EMAIL_REPORT="$2"; shift;;
                    --reportType) FX_REPORT_TYPE="$2"; shift;;
                    --tags) FX_TAGS="$2"; shift;;
                    --) shift;;
             esac
             shift;
    done
    
#FX_USER=$1
#FX_PWD=$2
#FX_JOBID=$3
#REGION=$4
#FX_ENVID=$5
#FX_PROJECTID=$6
#FX_EMAIL_REPORT=$7
#FX_TAGS=$8

FX_SCRIPT=""
if [ "$FX_TAGS" != "" ];
then
FX_SCRIPT="&tags=script:"+${FX_TAGS}
fi

token=$(curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${FX_USER}'", "password": "'${FX_PWD}'"}' https://cloud.fxlabs.io/login | jq -r .token)

echo "generated token is:" $token

URL="https://cloud.fxlabs.io/api/v1/runs/project/${FX_PROJECT_NAME}?jobName=${JOB_NAME}&region=${REGION}&emailReport=${FX_EMAIL_REPORT}&reportType=${FX_REPORT_TYPE}${FX_SCRIPT}"

url=$( echo "$URL" | sed 's/ /%20/g' )

runId=$(curl -s --location --request POST "$url" --header "Authorization: Bearer "$token"" | jq -r '.["data"]|.id')

echo "runId =" $runId
if [ -z "$runId" ]
then
          echo "RunId = " "$runId"
          echo "Invalid runid"
          echo $(curl -s --location --request POST "https://cloud.fxlabs.io/api/v1/runs/project/${FX_PROJECT_NAME}?jobName=${JOB_NAME}&region=${REGION}&emailReport=${FX_EMAIL_REPORT}&reportType=${FX_REPORT_TYPE}${FX_SCRIPT}" --header "Authorization: Bearer "$token"" | jq -r '.["data"]|.id')
          exit 1
fi


taskStatus="WAITING"
echo "taskStatus = " $taskStatus



while [ "$taskStatus" == "WAITING" -o "$taskStatus" == "PROCESSING" ]
         do
                sleep 5
                 echo "Checking Status...."

                passPercent=$(curl -s --location --request GET "https://cloud.fxlabs.io/api/v1/runs/${runId}" --header "Authorization: Bearer "$token""| jq -r '.["data"]|.ciCdStatus')

                        IFS=':' read -r -a array <<< "$passPercent"

                        taskStatus="${array[0]}"

                        echo "Status =" "${array[0]}" " Success Percent =" "${array[1]}"  " Total Tests =" "${array[2]}" " Total Failed =" "${array[3]}" " Run =" "${array[6]}"
                      # VAR2=$(echo "Status =" "${array[0]}" " Success Percent =" "${array[1]}"  " Total Tests =" "${array[2]}" " Total Failed =" "${array[3]}" " Run =" "${array[6]}")      


                if [ "$taskStatus" == "COMPLETED" ];then
            echo "------------------------------------------------"
                       # echo  "Run detail link https://cloud.fxlabs.io/${array[7]}"
                        echo  "Run detail link https://cloud.fxlabs.io${array[7]}"
                        echo "-----------------------------------------------"
                        echo "Scan Successfully Completed"
                        
                        # Determine if test passes for CI 
                        failedTestCount="${array[3]}"
                        if [ "$failedTestCount" -gt 0 ];then
                        testPass="FALSE"
                        echo "API Security Scan FAILURE due to" "$failedTestCount" "failed tests." "Halting build."
                        exit 1
                        fi
                        
                        if [ "$failedTestCount" == 0 ];then
                        testPass="True"
                        echo "API Security Scan SUCCESS. Build pipeline will continue."              
                        exit 0
                        fi

                fi
        done

if [ "$taskStatus" == "TIMEOUT" ];then
echo "Task Status = " $taskStatus
 exit 1
fi

echo "$(curl -s --location --request GET "https://cloud.fxlabs.io/api/v1/runs/${runId}" --header "Authorization: Bearer "$token"")"
exit 1

return 0
