# 校园一卡通（cycwc.cqmu.edu.cn:38080）接口清单

> 真实接口地址：`http://cycwc.cqmu.edu.cn:38080`  
> 来源：`/wxmp/` 单页应用中全部 `basePath + "/xxx"` 调用，按该端口地址整理  
> 说明：除登录相关接口外，以下均为该地址下的业务接口及其传参方式。

## 一、通用约定

| 项目 | 约定 |
| --- | --- |
| Base URL | `http://cycwc.cqmu.edu.cn:38080` |
| 请求体 | `Content-Type: application/x-www-form-urlencoded`（文件上传除外） |
| 鉴权 | 请求头 `accessToken: <登录返回的 accessToken>`，表中“鉴权”列为 ✅ 的接口需要 |
| 响应 | `{"status":"SUCCESS|FAIL","message":"...","data":...}` |
| 密码加密 | AES-128-ECB / PKCS7，密钥 `lyy4pGK2Iw0XtQPq`，输出 Base64 |
| 公共参数 | `userId` = 登录返回 `userId`；`userNo` = 学号/工号；`openId` = 微信 openId |
| 文件上传 | `multipart/form-data`，见 `/filecontroller/upload` |

> 表中 `userId` / `userNo` / `openId` / `token` 均取自登录成功后的本地会话；`—` 表示该接口无固定参数或由页面组装对象整包提交。

## 二、登录相关接口

### 2.1 密码登录

```
POST /login/doLogin
Content-Type: application/x-www-form-urlencoded
```

| 参数 | 必填 | 说明 |
| --- | --- | --- |
| `userno` | 是 | 学号 / 工号 / 身份证号 |
| `password` | 是 | 明文密码经 AES-128-ECB/PKCS7 加密后的 Base64 |
| `openId` | 是 | 微信 openId（优先取内存值，否则取本地缓存 `new_openId`） |
| `validateCode` | 否 | 图形验证码内容，与 `token` 成对使用 |
| `token` | 否 | 图形验证码随机串（先调 `GET /captcha/captchaImage?token=xxx`） |
| `loginCode` | 否 | 短信验证码（先调 `/employee/sendLoginCode`） |

Python 等价加密：

```python
from Crypto.Cipher import AES
from Crypto.Util.Padding import pad
import base64

def encrypt_password(plain: str) -> str:
    cipher = AES.new(b"lyy4pGK2Iw0XtQPq", AES.MODE_ECB)
    return base64.b64encode(cipher.encrypt(pad(plain.encode(), 16))).decode()
```

登录成功返回的 `data` 中取 `accessToken`、`userId`、`userNo`、`userName`、`departmentName`，后续请求作为会话使用。

### 2.2 其他登录 / 认证接口

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/captcha/captchaImage` | GET | token=randomStr | ✅ |
| `/employee/sendLoginCode` | POST | userNo=acount | — |
| `/login/bind` | POST | userNo=accountNo, password=accountPassward, openId=openId | — |
| `/login/loginAlumni` | POST | xyToken=token | — |
| `/login/loginUser` | POST | ticket, applyid, url=window.location.href.split("&ticket")[0] | — |
| `/login/openId` | POST | code=weixincode | — |
| `/login/resetpw` | POST | code=reset.verifyCode, pwd=encrypt(reset.password1), repwd=encrypt(reset.password2), empId=reset.empId, tel=reset.tel | ✅ |
| `/login/sendCode` | POST | empId=userId, tel=reset.tel | ✅ |
| `/login/ticketLogin` | POST | JSessionId=ticket, code=weixincode, timestamp=new Date().getTime() | — |
| `/login/unBind` | POST | userId=userId, openId=currentUser.openId | ✅ |
| `/login/unBindWechat` | POST | userno=currentUser.userNo, openId=openId, password=input | ✅ |

## 三、业务接口

### 3.1 人员 / 账户

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/employee/account` | POST | empId=userId | ✅ |
| `/employee/bed/select/page` | POST | page=1, reside, employeeNo, empmodelity, pageSize=10 | ✅ |
| `/employee/bed/select/total` | POST | page=1, reside, employeeNo, empmodelity, pageSize=10 | ✅ |
| `/employee/check` | POST | empId=currrentEmpId/empId, pwd=input | ✅ |
| `/employee/college/all` | POST | — | ✅ |
| `/employee/extend/get` | POST | empId=userId | ✅ |
| `/employee/extend/modify` | POST | — | ✅ |
| `/employee/facephotocheck` | POST | — | ✅ |
| `/employee/fogetpwd` | POST | userNo=reset.acount, code=reset.verifyCode, pwd=encrypt(reset.password1), rePwd=encrypt(reset.password2) | ✅ |
| `/employee/sendForgetCode` | POST | userNo=reset.acount | — |

### 3.2 菜单 / 基础配置

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/baseconfig/v2/gustMenu` | POST | — | — |
| `/baseconfig/v2/menus` | POST | userId=userId | — |

### 3.3 校园卡

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/card/info/addBank` | POST | employeeId=userId, accountNo=accountNo, bankType=bankType, signType=signType, telNo=telNo | ✅ |
| `/card/info/bank/binding` | POST | employeeId=userId, bankNo=banCardNo, bankType=bankType, doFlag=0/1 | ✅ |
| `/card/info/bank/get` | POST | empId=userId | ✅ |
| `/card/info/bank/getBankType` | POST | — | ✅ |
| `/card/info/delBank` | POST | employeeId=userId | ✅ |
| `/card/info/get` | POST | empId=userId | ✅ |
| `/card/info/getBankBangDing` | POST | employeeId=userId | ✅ |
| `/card/status/loss` | POST | cardId=cardInfo.cardId, passWord=input | ✅ |
| `/card/status/sendUnlockCode` | POST | empId=userId | ✅ |
| `/card/status/unloss` | POST | cardId=cardInfo.cardId, passWord=unlock_pwd, code=tel_code | ✅ |
| `/card/tempcard/applyTempCard` | POST | applyName, telno | ✅ |
| `/card/tempcard/cancelApply` | POST | ids, status=0 | ✅ |
| `/card/tempcard/changeTempCard` | POST | applyReason=userInfo.applyReason, deptId=userInfo.deptId, employeeId=userInfo.employeeId, openid=openId | ✅ |
| `/card/tempcard/getApplyListByAuditor` | POST | page=page, pageSize=pageSize, status=status, startTime=startTime, endTime=endTime, auditorNo=auditorNo | ✅ |
| `/card/tempcard/getApplyListByOpenid` | POST | page=1, pageSize=100, openid=openId | ✅ |
| `/card/tempcard/getChangeListByAuditor` | POST | page=page, pageSize=pageSize, status=status, startTime=startTime, endTime=endTime, auditorNo=auditorNo | ✅ |
| `/card/tempcard/getChangeListByEmpId` | POST | page=1, pageSize=100, openid=openId, employeeId=userId | ✅ |
| `/card/tempcard/getDepartmentList` | POST | — | ✅ |
| `/card/tempcard/getTempCardInfo` | POST | — | ✅ |
| `/card/tempcard/verifyApply` | POST | ids, refuseReason, status, validEndDate, fileUrl=fileUrl | ✅ |
| `/card/tempcard/verifyChange` | POST | ids, refuseReason, status, validEndDate, fileUrl=fileUrl | ✅ |
| `/card/transaction/page` | POST | page=1, empId, startTime, endTime, pageSize=10, accountType=2, walletId=0 | ✅ |

### 3.4 电子卡 / 付款码

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/eaccount/info` | POST | empId=userId | ✅ |
| `/eaccount/pay/check` | POST | empId=currrentEmpId/empId | ✅ |
| `/eaccount/pay/sweep` | POST | deviceNo=devicePay.deviceNo, walletId=devicePay.walletId, amount=devicePay.price, empId=empId | ✅ |
| `/eaccount/transKey` | POST | empId=userId/currrentEmpId | ✅ |
| `/eaccount/transKey/result` | POST | empId=currrentEmpId, qrCode=qrCode | ✅ |

### 3.5 缴费

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/fee/balance/queryRechargePage` | POST | page=1, empId, startTime, endTime, walletId=0, pageSize=10 | ✅ |
| `/fee/balance/wxCancelRecharge` | POST | orderNo=orderNo | ✅ |
| `/fee/balance/wxPayRecharge` | POST | totalAmount=金额, employeeId=userId, rechargeType=1/2, WalletId=walletId, openId=openId, operator=currentUser.userNo | ✅ |
| `/fee/dk/dkConfirm` | POST | totalAmount=金额, operator=currentUser.userNo, loanId=loan.id, executespanId=loan.executespanid, loanAmount=金额, employeeId=userId, payInfoParamList=itemList | ✅ |
| `/fee/dk/dkRefund` | POST | operator=currentUser.userNo, loanId=loan.id, tfAmount=tfamount, employeeId=userId | ✅ |
| `/fee/dk/getDkFeeList` | POST | employeeid=userId | ✅ |
| `/fee/ele/getArea` | POST | — | ✅ |
| `/fee/ele/getBuild` | POST | areaId=areaId | ✅ |
| `/fee/ele/getMeter` | POST | roomId=roomId | ✅ |
| `/fee/ele/getMeterDayValueBySf` | POST | openid, startDate, endDate, amMeterID | ✅ |
| `/fee/ele/getOutBuild` | POST | — | ✅ |
| `/fee/ele/getRoom` | POST | buildId=obj.buildId, floor=obj.value | ✅ |
| `/fee/ele/getRoomBalance` | POST | empId=userId, amMeterID=roomId | ✅ |
| `/fee/ele/getRoomBalanceBySf` | POST | amMeterID=amMeterID | ✅ |
| `/fee/ele/meterOnOff` | POST | amMeterID=selected.roomId, flag=val == 'on' ? 1 : 0 | ✅ |
| `/fee/ele/queryEleRechargePage` | POST | page=1, empId, startTime, endTime, pageSize=10 | ✅ |
| `/fee/ele/wxCancelEleRecharge` | POST | orderNo=orderNo | ✅ |
| `/fee/ele/wxCancelEleRechargeBySf` | POST | orderNo=orderNo | ✅ |
| `/fee/ele/wxPayEleRecharge` | POST | totalAmount=金额, operator=currentUser.userNo/userNo, openId=openId, employeeId=userId, rechargeType=1, roomNo=selected.roomNo, areaId=selected.areaID, roomId=selected.roomId | ✅ |
| `/fee/ele/wxPayEleRechargeBySf` | POST | totalAmount=金额, operator=zzjf/currentUser.userNo, openId=openId, employeeId=-1/userId, rechargeType=1, billType=selected.billType, billingNo=selected.billingNo, billingName=selected.billingName, telNo=selected.telNo, email=selected.email, roomNo=selected.roomNo, areaId=0002/selected.areaID, buildId=selected.architectureID, roomInfo=selected.architectureName + '-' + selected .floorName + '-' + selected.roomNo, roomId=selected.roomId | ✅ |
| `/fee/feecollectYlmz/payOtherYlmz` | POST | financingId=payothers.financingId, employeeNo=payothers.idcode, name=payothers.name, payWay=payway, phone=payothers.phoneNum, email=payothers.email, departmentId=payothers.departmentId, amount=金额, remark=payothers.remark, type=userType, yy=payothers.yy, jcxm=payothers.jcxm, openId=openId | ✅ |
| `/fee/feecollectYlmz/ylmzFinanceList` | POST | — | ✅ |
| `/fee/feecollectYlmz/ylmzYyList` | POST | — | ✅ |
| `/fee/generation/getGenerationList` | POST | employeeNo=currentUser.userNo | ✅ |
| `/fee/generation/wxCancelGenerationFee` | POST | orderNo=orderNo | ✅ |
| `/fee/generation/wxPayGenerationFee` | POST | totalAmount=金额, operator=currentUser.userNo, openId=openId, employeeId=userId, payInfoParamList=itemList | ✅ |
| `/fee/mtnPark/findCarFeeByUser` | POST | parkinfoid=parkinfoid | — |
| `/fee/mtnPark/getCarFeeAmount` | POST | month=month, unitprice=unitprice, standard=parkstandardid | ✅ |
| `/fee/mtnPark/getMtnCarNum` | POST | carNo=carNumber | ✅ |
| `/fee/mtnPark/getMtnCarSelect` | POST | cardno=currentUser.userNo | ✅ |
| `/fee/mtnPark/getMtnCarSelectCarNo` | POST | carNo=carNumber | ✅ |
| `/fee/mtnPark/wxCancelMtnCarFee` | POST | orderNo=orderNo | ✅ |
| `/fee/mtnPark/wxPayMtnCarFee` | POST | employeeno=currentUser.userNo, payWay=payway, openId=openId, amount=金额, cardid=cardid, startdate=startdate, enddate=enddate, cardEndDay=cardEndDay, unitprice=unitprice, totalcount=monthcount, tel=tel, email=email | ✅ |
| `/fee/parking/calMonthParkingFee` | POST | parkStandardId=currentParkstandard.parkStandardId, monthCount=month | ✅ |
| `/fee/parking/getEmployeePlate` | POST | cardno=currentUser.userNo | ✅ |
| `/fee/parking/wxPayCarMonthFee` | POST | parkinfoId=parkinfoId, payWay=payway, openId=openId, amount=金额, startTime=startdate, endTime=enddate, tel=tel, email=email, starndId=currentParkstandard.parkStandardId, count=monthcount, userNo=currentUser.userNo | ✅ |
| `/fee/receivable/report/detail/detail` | POST | empId=userId, departmentId=selectedDepartment.departmendId | ✅ |
| `/fee/receivable/report/detail/list` | POST | empId=userId, departmentId=department.departmendId | ✅ |
| `/fee/receivable/report/detail/page` | POST | page=1, departmentId, employeeNo, empId, pageSize=10 | ✅ |
| `/fee/receivable/report/list` | POST | empId=userId | ✅ |
| `/fee/receivable/report/total/list` | POST | empId=userId | ✅ |
| `/fee/receivable/statistics/page` | POST | page=1, pageSize=10, collegeId, type, startTime, endTime, grade | ✅ |
| `/fee/receivable/statistics/total` | POST | page=1, pageSize=10, collegeId, type, startTime, endTime, grade | ✅ |
| `/fee/receivableInfo/detailList` | POST | receivableaccountId=receivableAccountId | ✅ |
| `/fee/receivableInfo/freeList` | POST | receivableaccountId=receivableAccountId | ✅ |
| `/fee/receivableInfo/getFeeScore` | POST | receivableaccountId=receivableAccountId | ✅ |
| `/fee/receivableInfo/getFeeScoreEmp` | POST | employeeId=userId | ✅ |
| `/fee/receivableInfo/refundList` | POST | receivableaccountId=receivableAccountId, page=1, openid, startTime, endTime, empId, pageSize=10 | ✅ |
| `/fee/receivableInfo/totalList` | POST | employeeNo=page.employeeNo | ✅ |
| `/fee/receivableOut/getCollectBillHis` | POST | openId=payInfo.openId, billType=payInfo.billType | — |
| `/fee/receivableOut/getFeeDetailList` | POST | payerNo=payerNo, openId=openId | — |
| `/fee/receivableOut/getFeeDetailList_bmsd` | POST | payerNo=payerNo, openId=openId | — |
| `/fee/receivableOut/getFeeList` | POST | payerNo=payerNo, payerName=payerName, payStatus=0 | — |
| `/fee/receivableOut/getFeeList_bmsd` | POST | payerNo=payerNo, payStatus=0 | — |
| `/fee/receivableOut/wxPayReceivableOutFee` | POST | billType=1, billingName, billingNo, telNo, email, openId, operator, payerName, totalAmount=0, payInfoParamList=[] | ✅ |
| `/fee/refund/apply` | POST | reasonId=reasonId, bankType=bankType, bankNo=banCardNo, bankInfo=bankInfo, tel=tel, ids=refundData.receivableaccountid | ✅ |
| `/fee/refund/page` | POST | page=1, openid, startTime, endTime, empId, pageSize=10 | ✅ |
| `/fee/roomele/getMeterDayValue` | POST | startDate, endDate, amMeterID | ✅ |
| `/fee/roomele/getRoomBalance` | POST | empId=userId | ✅ |
| `/fee/roomele/queryEleRechargePage` | POST | roomId, page=1, pageSize=10, startTime, endTime | ✅ |
| `/fee/roomele/wxPayEleRecharge` | POST | totalAmount=金额, operator=currentUser.userNo, openId=openId, employeeId=userId, rechargeType=1, roomId=roomRelation.roomId | ✅ |
| `/fee/study/getStudyFeeList` | POST | employeeNo=userNo/currentUser.userNo, feeType=0 | ✅ |
| `/fee/study/scoreSettlement` | POST | employeeId=userId | ✅ |
| `/fee/study/wxCancelStudyFee` | POST | orderNo=orderNo | ✅ |
| `/fee/study/wxPayStudyFee` | POST | totalAmount=金额, operator=userNo/currentUser.userNo, openId=openId, employeeId=userId, payInfoParamList=itemList, isDk=loanSwitch ? 1 : 0 | ✅ |
| `/fee/tempPark/getNearestCarNo` | POST | openId=openId | — |
| `/fee/tempPark/getTempCarFee` | POST | carNo=fullCarNo | — |
| `/fee/tempPark/getTempCarFeeEntrance` | POST | ctrlNo=ctrlNo | — |
| `/fee/tempPark/page` | POST | page=1, openid, startTime, endTime, pageSize=10 | — |
| `/fee/tempPark/wxCancelTempCarFee` | POST | orderNo=orderNo | — |
| `/fee/tempPark/wxPayTempCarFee` | POST | carNo=payOrder.carNo/payOrder.fullCarNo, beginTime=payOrder.enterTime, carSysOrderNo=payOrder.orderNo, orderAmount=金额, openId=openId, ctrlNo=ctrlNo | — |
| `/fee/tender/applyRefundTender` | POST | id, openid=openId | ✅ |
| `/fee/tender/getBillFile` | POST | id | ✅ |
| `/fee/tender/getPerformByCode` | POST | — | ✅ |
| `/fee/tender/getTenderItemObj` | POST | id=param.id | ✅ |
| `/fee/tender/payPerform` | POST | money, payWayId, payerNo, phone | ✅ |
| `/fee/tender/payPerformByBh` | POST | — | ✅ |
| `/fee/tender/payTender` | POST | — | ✅ |
| `/fee/tender/sendMsgCode` | POST | id=item.id, money=item.amount | ✅ |
| `/fee/tender/tenderCollectList` | POST | openId=openId | ✅ |
| `/fee/tender/tenderItemList` | POST | isFee=1/0, itemName=param.keyWord | ✅ |
| `/fee/tender/uploadPerformBill` | POST | — | ✅ |
| `/fee/tender/uploadTenderBill` | POST | — | ✅ |
| `/fee/waterEle/addWaterEleFee` | POST | roomId, endNum, employeeNo, fileUrl | ✅ |
| `/fee/waterEle/getEmployeeRoom` | POST | employeeId=userId | ✅ |
| `/fee/waterEle/getRoomForFee` | POST | employeeId=userId | ✅ |
| `/fee/waterEle/getWaterEleFeeList` | POST | roomNo=roomNo, status=radio | ✅ |
| `/fee/waterEle/queryWaterFeeRoomPage` | POST | page=1, empId, startTime, endTime, pageSize=10 | ✅ |
| `/fee/waterEle/wxPayWaterEleFee` | POST | totalAmount=金额, operator=userNo, openId=openId, employeeId=userId, payInfoParamList=itemList | ✅ |

### 3.6 水控

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/water/getEmployeeRoom` | POST | employeeId=userId | ✅ |
| `/water/page` | POST | page=1, rechargeDate, empId, pageSize=10, roomName, empNo, status | ✅ |
| `/water/recharge` | POST | amount=金额, empId=userId, empNo=currentUser.userNo, empName=currentUser.userName, roomId=cardInfo.roomId, roomName=cardInfo.roomName, tel=cardInfo.tel, payType=1, openId=openId | ✅ |
| `/water/sure` | POST | confirmEmpId=userId, confirmEmpName=currentUser.userName, id=records[idx].id | ✅ |
| `/water/water/bindingSet` | POST | deviceno=deviceno, roomno=roomno | ✅ |
| `/water/water/getDorm` | POST | roomname=roomname | ✅ |
| `/water/water/getWaterDevicestate` | POST | page=1, pageSize=24, empId, state, deviceNo | ✅ |
| `/water/water/getWaterOrderPageByMarket` | POST | page=1, pageSize=10, startDate, endDate, empId, deviceNo, openid, startTime, endTime, transCode=1015, accountType=2 | ✅ |
| `/water/water/getWaterSumByRoom` | POST | page=1, pageSize=10, empId, startDate, endDate, roominfo | ✅ |
| `/water/water/getWaterTotal` | POST | startDate, endDate, empId | ✅ |
| `/water/water4G/activesetttleaccounts` | POST | ordersn=ordersn/m.ORDERSN | ✅ |
| `/water/water4G/bindDevice` | POST | deviceType=deviceType, deviceNo=deviceno, dormName=roomNo | ✅ |
| `/water/water4G/createorderissuccess` | POST | ordersn=ordersn | ✅ |
| `/water/water4G/getLatestDeviceNo` | POST | empId=userId | ✅ |
| `/water/water4G/orderingTips` | POST | empid=empId, openid | ✅ |
| `/water/water4G/query4GWaterPage` | POST | page=1, openid, startTime, endTime, pageSize=10, transCode=1015, empId, accountType=2 | ✅ |
| `/water/water4G/queryRelationByDorm` | POST | dorminfo=searchDorminfo/roomKeyword | ✅ |
| `/water/water4G/scanning` | POST | deviceno=deviceno, empid=empId | ✅ |

### 3.7 停车申请

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/park/apply` | POST | platenumber=plateNumber, emptype, vehiclelicensename=vehiclelicenseName, relationship, tel, vehicletypeid=vehicletypeId, parkstandardid=parkstandard.parkStandardId, files=files, applytype=param.applytype, parkinfoId=param.parkinfoId, newendday | ✅ |
| `/park/apply/cance` | POST | applyId | ✅ |
| `/park/apply/page` | POST | page=page, pageSize=pageSize, status=status | ✅ |
| `/park/apply/verify` | POST | applyid=applyId, status=btnMode == 'PASS' ? 1 : 0, remark=verifyMsg | ✅ |
| `/park/apply/verify/page` | POST | page=page, pageSize=pageSize, status=status, platenumber=platenumber, applyid=loginByTicket_applyid | ✅ |
| `/park/month/apply/page` | POST | page=1, pageSize=1, status=11 | ✅ |
| `/park/month/calMonthParkingFee` | POST | parkStandardId=param.parkStandardId, monthCount=parking.count | ✅ |
| `/park/month/delay` | POST | groupId, emptype | ✅ |
| `/park/month/manager` | POST | empType | ✅ |
| `/park/month/parkingSpace` | POST | number=val.groupno, name=val.groupname, groupId=val.groupid, openId=openId / 'test', parkStandardId=val.parkstandardid, startTime | ✅ |
| `/park/month/pay` | POST | groupId, amount | ✅ |
| `/park/month/spaceCar` | POST | groupId=monthlyParkingSpaceId | ✅ |
| `/park/month/upload` | POST | — | ✅ |
| `/park/month/verify` | POST | remark | ✅ |
| `/park/month/verify/page` | POST | — | ✅ |

### 3.8 车辆票务

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/carController/carCallback` | POST | orderno=orderno, type=type | ✅ |
| `/carController/createqrcode` | POST | — | ✅ |
| `/carController/getCarNumWithPage` | POST | page=1, empId, size=10, carno | ✅ |
| `/carController/getCarSeat` | POST | carnum=carnum | ✅ |
| `/carController/getCarSetById` | POST | seatid=data.id | ✅ |
| `/carController/getOrderByEmpId` | POST | usestatus=0, empid, size=10, carnum | ✅ |
| `/carController/isbuyticket` | POST | carnum=carnum, empid=empid | ✅ |
| `/carController/isbuyticketnew` | POST | carnum=carnum, empid=empid | ✅ |
| `/carController/paywxcar` | POST | — | ✅ |
| `/carController/paywxcarnew` | POST | — | ✅ |
| `/carController/scanticket` | POST | — | ✅ |

### 3.9 车辆测速

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/carSpeedController/getCarHistoryList` | POST | — | ✅ |
| `/carSpeedController/getCarListWithPage` | POST | — | ✅ |
| `/carSpeedController/getCarRecordHistoryDetail` | POST | — | ✅ |
| `/carSpeedController/getCarSpeedDetail` | POST | type, id, starttime, endtime, speed | ✅ |
| `/carSpeedController/moveoutblack` | POST | szplatenumber=szplatenumber | ✅ |

### 3.10 宿舍床位

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/roombed/applyoutbed` | POST | empid=empId, bedid=bedInfo.bedId, outtime=outTime, empno=currentUser.userNo, modifyexplain=modifyexplain | ✅ |
| `/roombed/bed/history/page` | POST | page=1, empId, pageSize=10 | ✅ |
| `/roombed/employee/bed` | POST | empId=empId | ✅ |
| `/roombed/employee/bed/change/apply` | POST | empId=empId, bedId=bedInfo.bedId, roomId=bedInfo.roomId, applyExplain=applyExplain, applyBedId=bedid | ✅ |
| `/roombed/employee/bed/change/getChangeInfo` | POST | empId=empId | ✅ |
| `/roombed/employee/bed/change/sureBed` | POST | empId=empId, id=id, userName=userName | ✅ |
| `/roombed/modify/page` | POST | page=1, empId, pageSize=10 | ✅ |
| `/roombed/modifySelf/page` | POST | nj, xyid, zyid, bjid, page=1, empId, startTime, endTime, employeeNo, status, roomName, userNo, className, role=instrutorRole, area, pageSize=10, operatestatus | ✅ |
| `/roombed/modifySelf/verifyApply` | POST | applyId=applyId, status=status, userNo=page.userNo, role=page.role, userName=userName, afterbedid=afterbedid | ✅ |
| `/roombed/modifySelf/verifyApplyBatch` | POST | — | ✅ |
| `/roombed/modifySelf/verifyTotal` | POST | nj, xyid, zyid, bjid, page=1, empId, startTime, endTime, employeeNo, status, roomName, userNo, className, role=instrutorRole, area, pageSize=10, operatestatus | ✅ |
| `/roombed/newstu/bed` | POST | empId=empId | ✅ |
| `/roombed/newstu/cancelApply` | POST | empId=empId, bedId=bedid | ✅ |
| `/roombed/newstu/chechEmpModelity` | POST | empId=empId | ✅ |
| `/roombed/newstu/choose` | POST | empId=empId, bedId=bedid, employeeno=employeeno | ✅ |
| `/roombed/newstu/queryNewStuConfig` | POST | — | ✅ |
| `/roombed/queryBed` | POST | roomid=roomid/targetid, type=applybed/newStu | ✅ |
| `/roombed/queryBj` | POST | xyid=page.xyid, zyid=page.zyid, nj=page.nj | ✅ |
| `/roombed/queryModifyconfig` | POST | — | ✅ |
| `/roombed/queryNj` | POST | — | ✅ |
| `/roombed/queryRoom` | POST | parentid=targetid, type=applybed | ✅ |
| `/roombed/queryUserRole` | POST | userNo=page.userNo | ✅ |
| `/roombed/queryXy` | POST | — | ✅ |
| `/roombed/queryZy` | POST | xyid=page.xyid | ✅ |

### 3.11 校外人员 / 退宿

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/outEmployee/employee/page` | POST | page=1, empId, employeeNo, status, pageSize=10 | ✅ |
| `/outEmployee/employee/person/page` | POST | page=1, empId, pageSize=10 | ✅ |
| `/outEmployee/employee/teacher/page` | POST | page=1, empId, employeeNo, pageSize=10 | ✅ |
| `/outEmployee/employee/total` | POST | page=1, empId, employeeNo, status, pageSize=10 | ✅ |
| `/outEmployee/employee/verify` | POST | id=outEmpStateId, empId=page.empId | ✅ |
| `/outEmployee/employee/verify/batch` | POST | — | ✅ |
| `/outEmployee/employee/verify/cancel` | POST | id=outEmpStateId, empId=page.empId | ✅ |
| `/outEmployee/room/apply` | POST | empId=empId, bedId=bedInfo.bedId, roomId=bedInfo.roomId | ✅ |
| `/outEmployee/room/apply/get` | POST | empId=empId | ✅ |
| `/outEmployee/room/reApply` | POST | applyId=apply.applyId, empId=empId | ✅ |
| `/outEmployee/room/verify` | POST | applyId=applyId, status=status, outBedType=page.outBedType, empId=page.empId | ✅ |
| `/outEmployee/room/verify/batch` | POST | — | ✅ |
| `/outEmployee/room/verify/page` | POST | page=1, empId, startTime, endTime, employeeNo, status, roomName, className, area, pageSize=10, outBedType=0, operateStatus | ✅ |
| `/outEmployee/room/verify/total` | POST | page=1, empId, startTime, endTime, employeeNo, status, roomName, className, area, pageSize=10, outBedType=0, operateStatus | ✅ |

### 3.12 财务交易

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/transaction/account/page` | POST | financingId, executespanId, page=1, empId, pageSize=10, empName, payType=0 | ✅ |
| `/transaction/creditLoan/page` | POST | page=1, empId, pageSize=10 | ✅ |
| `/transaction/detail/list` | POST | receivableAccountId=selectRecord.receivableAccountId | ✅ |
| `/transaction/dzb/list` | POST | parentid=selectDzzId | ✅ |
| `/transaction/dzz/list` | POST | — | ✅ |
| `/transaction/executespan/list` | POST | empId=page.empId | ✅ |
| `/transaction/financing/batch` | POST | financingId=currentFinaceId | ✅ |
| `/transaction/financing/department/list` | POST | financeId=payothers.financingId | ✅ |
| `/transaction/financing/df/pay` | POST | financingId=payothers.financingId, employeeNo=payothers.idcode, name=payothers.name, payWay=payway, departmentIdJf=payothers.dzbId, phone=payothers.phoneNum, email=payothers.email, departmentId=payothers.departmentId, amount=金额, remark=payothers.remark, month=payothers.month, type=userType, openId=openId | ✅ |
| `/transaction/financing/list` | POST | empId=page.empId | ✅ |
| `/transaction/financing/meeting/pay` | POST | financingId=payothers.financingId, employeeNo=payothers.idcode, name=payothers.name, payWay=payway, phone=payothers.phoneNum, email=payothers.email, departmentId=payothers.departmentId, amount=payothers.defaultAmount, unitName=payothers.unitName, accountNo=payothers.accountNo, bankName=payothers.bankName, unitCode=payothers.unitCode, remark=payothers.remark, type=userType, represent=selectedPayUserType, batchName=payothers.batchName, batchid=payothers.batchid, openId=openId, batchitemid=payothers.batchitemid | ✅ |
| `/transaction/financing/other/cancel` | POST | orderNo=orderNo, payway=payway | ✅ |
| `/transaction/financing/other/list` | POST | — | ✅ |
| `/transaction/financing/other/page` | POST | page=1, openid, startTime, endTime, empId, pageSize=10 | ✅ |
| `/transaction/financing/other/pay` | POST | financingId=payothers.financingId, employeeNo=currentUser.userNo, name=currentUser.userName, payWay=payway, openId=openId | ✅ |
| `/transaction/financing/receipt/pay` | POST | financingId=payothers.financingId, employeeNo=payothers.idcode, name=payothers.name, payWay=payway, phone=payothers.phoneNum, email=payothers.email, departmentId=payothers.departmentId, amount=payothers.defaultAmount, unitName=payothers.unitName, accountNo=payothers.accountNo, bankName=payothers.bankName, unitCode=payothers.unitCode, remark=payothers.remark, type=userType, represent=payUserType, openId=openId | ✅ |
| `/transaction/financing/train/pay` | POST | financingId=payothers.financingId, employeeNo=payothers.idcode, name=payothers.name, payWay=payway, phone=payothers.phoneNum, email=payothers.email, departmentId=payothers.departmentId, amount=payothers.defaultAmount, unitName=payothers.unitName, accountNo=payothers.accountNo, bankName=payothers.bankName, unitCode=payothers.unitCode, remark=payothers.remark, type=userType, represent=selectedPayUserType, batchName=payothers.batchName, batchid=payothers.batchid, openId=openId, batchitemid=payothers.batchitemid | ✅ |
| `/transaction/financing/visit/list` | POST | financeId=currentFinaceId | ✅ |
| `/transaction/financing/visit/page` | POST | page=1, openid, startTime, endTime, empId, pageSize=10, employeeNo, name, telNo | ✅ |
| `/transaction/financing/visit/pay` | POST | financingId=payothers.financingId, employeeNo=payothers.idcode, name=payothers.name, payWay=payway, phone=payothers.phoneNum, email=payothers.email, departmentId=payothers.departmentId, amount=payothers.defaultAmount/金额, remark=payothers.remark, type=userType, openId=openId | ✅ |
| `/transaction/subsidy/page` | POST | page=1, empId, startTime, endTime, transCode=0, pageSize=10 | ✅ |

### 3.13 商铺缴费

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/shop/ele/getShopWaterFeeList` | POST | shopname=shopname | ✅ |
| `/shop/ele/getShopWaterFeeListPage` | POST | page=1, empId, shopname, pageSize=10 | ✅ |
| `/shop/ele/wxCancelWaterFee` | POST | orderNo=orderNo | ✅ |
| `/shop/ele/wxPayShopWaterFee` | POST | totalAmount=金额, openId=openId, payInfoParamList=itemList | ✅ |
| `/shop/rent/checkShopPassword` | POST | shopno=shopname/page.shopname, password=input | ✅ |
| `/shop/rent/getRentFeeList` | POST | shopname=shopname | ✅ |
| `/shop/rent/getRentFeeListPage` | POST | page=1, empId, shopname, pageSize=10 | ✅ |
| `/shop/rent/getShopConsume` | POST | page=1, empId, starttime, endtime, pageSize=10, timetype=1, paytype, querytype, userno | ✅ |
| `/shop/rent/wxCancelRentFee` | POST | orderNo=orderNo | ✅ |
| `/shop/rent/wxPayRentFee` | POST | totalAmount=金额, openId=openId, payInfoParamList=itemList | ✅ |

### 3.14 食堂订餐

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/dinner/order` | POST | empId=userId, empNo=currentUser.userNo, empName=currentUser.userName, roomName=cardInfo.roomName, roomId=cardInfo.roomId, orderDate=cardInfo.day, orderType=cardInfo.type, remark=cardInfo.remark | ✅ |
| `/dinner/page` | POST | page=1, dinnerDate, orderDate, orderType, empId, pageSize=10 | ✅ |

### 3.15 信用支付

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/credit/apply` | POST | empId, amount=0, creditType, applyFlag, mediaId, typeArray=[] | ✅ |
| `/credit/apply/get` | POST | empId=userId | ✅ |
| `/credit/cancel` | POST | empId, amount=0, creditType, applyFlag, mediaId, typeArray=[] | ✅ |
| `/credit/creditAudit` | POST | id=selectRecord.id, auditStatus=type, verifyEmpNo=userNo, remark=selectRecord.remark | ✅ |
| `/credit/creditAudit/page` | POST | page=1, pageSize=10, collegeId, studentType, creditType, employeeNo, auditStatus, startTime, endTime, grade | ✅ |
| `/credit/type/list` | POST | — | ✅ |

### 3.16 财务查询

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/cwc/billinfo` | POST | — | — |
| `/cwc/traffic` | POST | — | — |
| `/cwc/travel` | POST | — | — |

### 3.17 消费统计

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/market/transaction/sum/page` | POST | page=1, empId, type=1, accountType, deviceNo, startTime, endTime, pageSize=10 | ✅ |

### 3.18 通知

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/notice/tops` | POST | — | ✅ |

### 3.19 设备支付

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/device/payInfo` | POST | deviceNo=deviceNo | ✅ |

### 3.20 门锁

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/lock/getPwd` | POST | — | ✅ |

### 3.21 门禁记录

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/rola/getRolaRecord` | POST | page=1, starttime, endtime, empno, size=10 | ✅ |

### 3.22 后勤

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/hqc/location/apply` | POST | areaType, empId, empName, empNo, buildingName, areaName, roomName, jdName, sqName, doorName | ✅ |
| `/hqc/location/empId` | POST | empId=userId | ✅ |

### 3.23 离校

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/leave/getLeaveFee` | POST | empId=empId | ✅ |

### 3.24 工资查询

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/wxgzxx/querySalaryDetails` | POST | employeeno=currentUser.userNo, nd=parent.salaryRecord.nd | ✅ |
| `/wxgzxx/querySalaryTotal` | POST | employeeno=currentUser.userNo, nd=nd | ✅ |

### 3.25 微信缴费

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/wechat/fee/df/getDfFee` | POST | openId=openId, employeeId, employeeno=userNo, payType=1 | ✅ |
| `/wechat/fee/df/getLtxDyListByZb` | POST | month=month, departmentId=departmentId | ✅ |
| `/wechat/fee/df/getLtxPayMonth` | POST | — | ✅ |
| `/wechat/fee/df/getLtxZbList` | POST | month=month | ✅ |
| `/wechat/fee/df/getPayDFList` | POST | page=1, pageSize=5, startTime, endTime, tradeType=1, openId=openId | ✅ |
| `/wechat/fee/df/payDfFeeBig` | POST | — | ✅ |

### 3.26 文件上传

| 接口 | 方法 | 参数 | 鉴权 |
| --- | --- | --- | --- |
| `/filecontroller/upload` | POST | — | ✅ |
