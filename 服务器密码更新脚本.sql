--创建 服务器配置表 serverconfig
-- Create table
create table SERVERCONFIG
(
  id              NUMBER not null primary key,
  server_alias    VARCHAR2(200),
  servernumber    VARCHAR2(200),
  prefecture      VARCHAR2(200),
  ip              VARCHAR2(200),
  username        VARCHAR2(200),
  pwd             VARCHAR2(200),
  last_updatetime DATE,
  updatetimes     NUMBER
);
-- Add comments to the columns 
comment on column SERVERCONFIG.server_alias
  is '服务器别称';
comment on column SERVERCONFIG.servernumber
  is '服务器编号';
comment on column SERVERCONFIG.prefecture
  is '地区';
comment on column SERVERCONFIG.ip
  is 'IP地址，加端口号，如果有多个IP地址以,分割具体如下:121.42.28.12:5339,192.168.10.1,192.168.0.9:123';
comment on column SERVERCONFIG.username
  is '服务器用户名';
comment on column SERVERCONFIG.pwd
  is '服务器密码';
comment on column SERVERCONFIG.last_updatetime
  is '最后一次更新时间';
comment on column SERVERCONFIG.updatetimes
  is '更新次数';
--unique and foreign key constraints 
alter table SERVERCONFIG
  add constraint UK_SERVERCONFIG unique (SERVERNUMBER, PREFECTURE, IP)
  using index 
  pctfree 10
  initrans 2
  maxtrans 255
  storage
  (
    initial 64K
    minextents 1
    maxextents unlimited
  );
-- Create 创建服务器配置表序列
create sequence SEQ_SERVERCONFIG_ID
minvalue 1
maxvalue 9999999999999999999
start with 1
increment by 1
cache 20;
-- Create table 创建服务器配置记录表 

create table SERVERCONFIG_RECORD
(
  id           NUMBER primary key,
  server_id    NUMBER,
  server_alias VARCHAR2(200),
  servernumber VARCHAR2(200),
  ip           VARCHAR2(200),
  username     VARCHAR2(200),
  pwd          VARCHAR2(200),
  updatetime   DATE,
  operator     VARCHAR2(200)
);
-- Add comments to the columns 
comment on column SERVERCONFIG_RECORD.server_id
  is '服务器ID';
comment on column SERVERCONFIG_RECORD.server_alias
  is '服务器别称';
comment on column SERVERCONFIG_RECORD.servernumber
  is '服务器编号';
comment on column SERVERCONFIG_RECORD.ip
  is 'ip地址';
comment on column SERVERCONFIG_RECORD.username
  is '用户名';
comment on column SERVERCONFIG_RECORD.pwd
  is '用户密码';
comment on column SERVERCONFIG_RECORD.updatetime
  is '更新时间';
comment on column SERVERCONFIG_RECORD.operator
  is '操作人';
-- Create sequence 创建服务器配置记录表序列
create sequence SEQ_SERVERCONFIG_RECORD_ID
minvalue 1
maxvalue 9999999999999999999
start with 1
increment by 1
cache 20;
--创建生成随机密码函数
CREATE OR REPLACE FUNCTION random_password(password_num in varchar2)
  RETURN VARCHAR2
  PARALLEL_ENABLE is
  optx char(1);
  rng  NUMBER;
  n    BINARY_INTEGER;
  ccs  VARCHAR2(128); -- candidate character subset
  xstr VARCHAR2(4000);
BEGIN
  FOR i IN 1 .. length(password_num)+1 LOOP
    /* Get random integer within specified range */
    n := TRUNC(rng * dbms_random.value) + 1;
    /* Append character to random_password2  */
    xstr := xstr || SUBSTR(ccs, n, 1);
    optx := SUBSTR(password_num, i, 1);
    IF optx = 'u' THEN
      -- upper case alpha characters only
      ccs := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      rng := 26;
    ELSIF optx = 'l' THEN
      -- lower case alpha characters only
      ccs := 'abcdefghijklmnopqrstuvwxyz';
      rng := 26;
    ELSIF optx = 'a' THEN
      -- alpha characters only (mixed case)
      ccs := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' || 'abcdefghijklmnopqrstuvwxyz';
      rng := 52;
    ELSIF optx = 'n' THEN
      -- any numeric characters (upper)
      ccs := '0123456789';
      rng := 10;
    ELSIF optx = 'x' THEN
      -- any special characters (upper)
      ccs := ' !"#$%&()*+,-./:;<=>?@';
      rng := 23;
    ELSIF optx = 'p' THEN
      -- any printable char (ASCII subset)
      ccs := ' !"#$%&''()*+,-./' || '0123456789' || ':;<=>?@' ||
             'ABCDEFGHIJKLMNOPQRSTUVWXYZ' || '[\]^_`' ||
             'abcdefghijklmnopqrstuvwxyz' || '{|}~';
      rng := 95;
     ELSIF optx = 'y' THEN
      -- any special characters (upper)
      ccs := '!"#$%&()*+-=?';
      rng := 13;
    ELSE
      ccs := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
      rng := 26; -- default to upper case
    END IF;

  END LOOP;
  RETURN xstr;
END random_password;
--创建修改密码存储过程
create or replace procedure change_passwords(queryString in varchar2,OPERATORs in varchar2,pwd out varchar2)  IS
begin
declare
    /**定义变量*/
  V_id serverconfig.id%type;
  V_pwd serverconfig.pwd%type;
  V_UPDATETIMES serverconfig.updatetimes%type;
  V_QueryS nvarchar2(200);
  begin
    V_QueryS:='%'||queryString||'%';
    dbms_output.put_line(V_QueryS);
          /***根据条件查询出需要更新的服务器,并对V_ID变量进行赋值**/
      select ID,      case when UPDATETIMES is null then 0 else UPDATETIMES end UPDATETIMES  
      into V_id,V_UPDATETIMES from serverconfig  
        where PREFECTURE like V_QueryS
              or IP like  V_QueryS
              or SERVER_ALIAS  like V_QueryS
              or SERVERNUMBER  like V_QueryS
              or ID like V_QueryS;
        /**根据设定规则生成随机密码*/
        select random_password('unnnlnnnnyyaay') into V_pwd from dual;
        /**将数据插入SERVERCONFIG_RECORD 服务器配置修改记录表中*/
        insert into SERVERCONFIG_RECORD(id, ip,username,pwd,updatetime,OPERATOR,server_alias,SERVERNUMBER,SERVER_ID) 
               select seq_serverconfig_record_id.nextval,t2.IP,t2.USERNAME,V_pwd,sysdate,OPERATORs,t2.server_alias,t2.servernumber,V_id from SERVERCONFIG t2
               where t2.id=V_id;
        /**将修改后的密码更新至SERVERCONFIG 服务器配置表中*/
        update  SERVERCONFIG a set(a.PWD,a.LAST_UPDATETIME,a.UPDATETIMES)=(
        select V_pwd,sysdate,V_UPDATETIMES+1 from SERVERCONFIG b  where a.id=b.id
        )where  id=V_id;
        /**提交数据修改*/
        commit;
        pwd:=V_pwd;
    end;
 end;
--创建 新登记服务器存储过程
create or replace procedure change_passwords_NewServer(
I_SERVER_ALIAS in varchar2, --服务器别称
I_SERVERNUMBER in varchar2, --服务器编号
I_PREFECTURE in varchar2, --省市县地区
I_IP in varchar2, --ip地址包含端口号
I_USERNAME in varchar2, --服务器用户名
I_PWD in varchar2,  --服务器密码
I_OPERATOR in varchar2,  --服务器操作员
o_pwd out varchar2 --输出服务器密码
)  IS
begin
declare
    /**定义变量*/
  V_id serverconfig.id%type;
  V_pwd serverconfig.pwd%type;
  begin
     /**如果未填写密码密码为空则生成随机密码*/
    if(I_PWD is null) then
             select random_password('unnnlnnnnyyaay') into V_pwd from dual;
        else
             V_pwd:=I_PWD;
     end if;
     /**生成change_passwords表的ID*/
      select seq_serverconfig_id.nextval into V_id from dual;
     /**将修改后的密码更新至SERVERCONFIG 服务器配置表中*/
        insert into  SERVERCONFIG(ID,SERVER_ALIAS,SERVERNUMBER,PREFECTURE,IP,USERNAME,PWD,LAST_UPDATETIME,UPDATETIMES)
        values(V_id,I_SERVER_ALIAS,I_SERVERNUMBER,I_PREFECTURE,I_IP,I_USERNAME,V_pwd,sysdate,1);


        /**将数据插入SERVERCONFIG_RECORD 服务器配置修改记录表中*/
        insert into SERVERCONFIG_RECORD(id, ip,username,pwd,updatetime,OPERATOR,server_alias,SERVERNUMBER,SERVER_ID)
               select seq_serverconfig_record_id.nextval,t2.IP,t2.USERNAME,V_pwd,sysdate,I_OPERATOR,t2.server_alias,t2.servernumber,V_id from SERVERCONFIG t2
               where t2.id=V_id;
        /**提交数据修改*/
        commit;
        o_pwd:=V_pwd;
    end;
 end;

