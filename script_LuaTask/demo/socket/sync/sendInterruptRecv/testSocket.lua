--- testSocket
-- @module testSocket
-- @author AIRM2M
-- @license MIT
-- @copyright openLuat.com
-- @release 2018.10.27
require "socket"
module(..., package.seeall)

-- 此处的IP和端口请填上你自己的socket服务器和端口
local ip, port = "180.97.80.55", 12415

--[[
TCP协议发送数据时，数据发送出去之后，必须等到服务器返回TCP ACK包，才认为数据发送成功，在网络较差的情况下，这种ACK确认就会导致发送过程很慢。
从而导致用户程序后续的AT处理逻辑一直处于等待状态。例如执行AT+CIPSEND动作发送一包数据后，接下来要执行AT+QTTS播放TTS，但是CIPSEND一直等了1分钟才返回SEND OK，
这时AT+QTTS就会一直等待1分钟，可能不是程序中想看到的。
此时就可以设置为快发模式，AT+CIPSEND可以立即返回一个结果，此结果表示“数据是否被缓冲区所保存”，从而不影响后续其他AT指令的及时执行

AT版本可以通过AT+CIPQSEND指令、Luat版本可以通过socket.setSendMode接口设置发送模式为快发或者慢发

快发模式下，在core中有一个1460*7=10220字节的缓冲区，要发送的数据首先存储到此缓冲区，然后在core中自动循环发送。
如果此缓冲区已满，则AT+CIPSEND会直接返回ERROR，socket:send接口也会直接返回失败

同时满足如下几种条件，适合使用快发模式：
1.	发送的数据量小，并且发送频率低，数据发送速度远远不会超过core中的10220字节大小；
    没有精确地判断标准，可以简单的按照3分钟不超过10220字节来判断；曾经有一个不适合快发模式的例子如下：
    用户使用Luat版本的http上传一个几十K的文件，设置了快发模式，导致一直发送失败，因为循环的向core中的缓冲区插入数据，
    插入数据的速度远远超过发送数据到服务器的速度，所以很快就导致缓冲区慢，再插入数据时，就直接返回失败
2.	对每次发送的数据，不需要确认发送结果
3.	数据发送功能不能影响其他功能的及时响应
]]
--socket.setSendMode(1)

-- tcp test
sys.taskInit(function()
    local r, s, p
    
    while true do
        while not socket.isReady() do sys.wait(1000) end
        local c = socket.tcp()
        while not c:connect(ip, port) do sys.wait(2000) end
        while true do
            r, s, p = c:recv(120000, "pub_msg")
            if r then
                log.info("这是收到了服务器下发的消息:", s)
            elseif s == "pub_msg" then
                log.info("这是收到了订阅的消息和参数显示:", s, p)
                if not c:send(p) then break end
            elseif s == "timeout" then
                log.info("这是等待超时发送心跳包的显示!")
                if not c:send("\0") then break end
            else
                log.info("这是socket连接错误的显示!")
                break
            end
        end
        c:close()
    end
end)

-- 测试代码,用于发送消息给socket
sys.taskInit(function()
    while true do
        sys.publish("pub_msg", "11223344556677889900AABBCCDDEEFF" .. os.time())
        sys.wait(180000)
    end
end)
