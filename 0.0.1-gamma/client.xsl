<?xml version='1.0'?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">


<xsl:template match="/">
<html>
<head>
<title>MPP Live Monitor</title>
<link href="/mppdoc/style.css" rel="styleSheet" type="text/css" />

<script id="1" type="text/javascript" src="/mppdoc/mppwebclient.js">
  var junk;
</script>

<script id="2" type="text/javascript">
var http = false;
var jsonRequestText = '<xsl:value-of select="groups/objects"/>';
var collectors;
var timerID;
var timerIDflag = 0;

if(navigator.appName == "Microsoft Internet Explorer") {
  http = new ActiveXObject("Microsoft.XMLHTTP");
} else {
  http = new XMLHttpRequest();
}

function collect() {
    if (timerIDflag == 1) {
        replaceobj(http,jsonRequestText);
    }
}
function startstopCollector() {
    if (timerIDflag == 0) {
        timerIDflag = 1;
        collect();
        timerID = setInterval("collect()",60000); // 60,000ms = 1 minute
    } else {
        timerIDflag = 0;
        clearInterval(timerID);
    }
}

//do on ready
function onReady()
{
    // alert("The DOM is ready!");
    startstopCollector();
}

//window.onload=windowinit;
//execute as soon as DOM is loaded
window.onDomReady(onReady);
</script>

</head>
<body>

<div id="header">
<h2>MPP Web Client</h2>
</div>

<div id="navbar">
<h4>NAV > Last Update <span id="NavLastUpdateTime">-</span></h4>
<ul>
  <li><span style="cursor: default" onclick="startstopCollector(),toggletext(this,'Start Updates','Stop Updates')">Stop Updates</span></li>
</ul>
</div>

<div id="mainwrapper">
<div id="controlpanel">
    <h2>Control Panel</h2>
</div>
<div id="monitorpanel">
    <xsl:apply-templates name="groups" select="/groups"/>
</div>
</div>

<div id="footer">
MPP
</div>

</body>
</html>
</xsl:template>

<xsl:template name="groups" match="groups">
        <xsl:apply-templates name="group" select="group"/>
</xsl:template>

<xsl:template name="group" match="group">
    <div id="groups" class="{@column}">
    <div id="group">
        <h1 class="groupname"><xsl:value-of select="@service"/> : <xsl:value-of select="@name"/></h1>
        <xsl:apply-templates name="group_pools" select="pools"/>
    </div>
    </div>
</xsl:template>

<xsl:template name="pools" match="pools">
    <div id="pools">
        <xsl:apply-templates name="pool" select="pool"/>
    </div>
</xsl:template>

<xsl:template name="pool" match="pool">
<div id="pool">
    <h1 class="poolname"><xsl:value-of select="@name"/></h1>
    <h1 class="poolstatus"> <div id="{status/obj/@id}" style="cursor: default" class="dynamic" onclick="toggle(this.parentNode.parentNode,'poolserver-checkpoint')"><xsl:value-of select="status/obj"/> </div> </h1>
    <div id="poolserver">
        <div id="poolserver-name"> name </div>
        <div id="poolserver-failover-type">   type   </div>
        <div id="poolserver-failover-state">  state  </div>
        <div id="poolserver-failover-status"> status </div>
    </div>
    <xsl:apply-templates name="poolserver" select="server"/>
</div>
</xsl:template>

<xsl:template name="poolserver" match="server">
<div id="poolserver">
    <div id="poolserver-name"> <xsl:value-of select="@name"/> </div>
    <div id="poolserver-failover-type">   <div id="{failover_type/obj/@id}" class="dynamic">   <xsl:value-of select="failover_type/obj"/>   </div></div>
    <div id="poolserver-failover-state">  <div id="{failover_state/obj/@id}" class="dynamic">  <xsl:value-of select="failover_state/obj"/>  </div></div>
    <div id="poolserver-failover-status"> <div id="{failover_status/obj/@id}" class="dynamic"> <xsl:value-of select="failover_status/obj"/> </div></div>
    <span class="toggle" onclick="toggle(this.parentNode,'poolserver-status'),toggletext(this,'[M+]','[M-]')">[M+]</span>
    <span class="toggle" onclick="toggle(this.parentNode,'poolserver-checkpoint'),toggletext(this,'[C+]','[C-]')">[C+]</span>
    <div id="poolserver-status" style="display: none">
        <div id="poolserver-status-lastrequesttime">   <span style="display:inline; position:relative; float:left; margin-right:1em;">Last Request:</span> <div id="{@serverlastrequesttimeid}" class="dynamic" style="display:inline; position:relative; float:left;">-</div>  </div>
        <div id="poolserver-status-numberofrequests">  <span style="display:inline; position:relative; float:left; margin-right:1em;">Errored Requests:</span> <div id="{@servernumberofrequestsid}" class="dynamic" style="display:inline; position:relative; float:left;">-</div> </div>
        <div id="poolserver-status-laststatusmessage"> <span style="display:inline; position:relative; float:left; margin-right:1em;">Error Message:</span> <div id="{@serverlaststatusmessageid}" class="dynamic" style="display:inline; position:relative; float:left;">-</div> </div>
    </div>
    <xsl:apply-templates name="poolservercheckpoint" select="checkpoint"/>
</div>
</xsl:template>

<xsl:template name="poolservercheckpoint" match="checkpoint">
    <div id="poolserver-checkpoint" style="display: none">
        <div id="poolserver-checkpoint-type">   <xsl:value-of select="@type"/> </div>
        <div id="poolserver-checkpoint-name">   <xsl:value-of select="@name"/> </div>
        <div id="poolserver-checkpoint-status"> <div id="{obj/@id}" class="dynamic"> <xsl:value-of select="obj"/>   </div></div>
        <span class="toggle" onclick="toggle(this.parentNode,'poolserver-checkpointserver-status'),toggletext(this,'[M+]','[M-]')">[M+]</span>
        <div id="poolserver-checkpointserver-status" style="display: none">
            <div id="poolserver-checkpointserver-status-lastrequesttime">   <span style="display:inline; position:relative; float:left; margin-right:1em;">Last Request:</span> <div id="{@serverlastrequesttimeid}" class="dynamic" style="display:inline; position:relative; float:left;">-</div>  </div>
            <div id="poolserver-checkpointserver-status-numberofrequests">  <span style="display:inline; position:relative; float:left; margin-right:1em;">Errored Requests:</span> <div id="{@servernumberofrequestsid}" class="dynamic" style="display:inline; position:relative; float:left;">-</div> </div>
            <div id="poolserver-checkpointserver-status-laststatusmessage"> <span style="display:inline; position:relative; float:left; margin-right:1em;">Error Message:</span> <div id="{@serverlaststatusmessageid}" class="dynamic" style="display:inline; position:relative; float:left;">-</div> </div>
        </div>
    </div>
</xsl:template>


<xsl:template match="polledserver">
</xsl:template>


<xsl:template name="getNameAttribute">
    <xsl:value-of select="@name"/>
</xsl:template>

<xsl:template name="getText" match="text">
    <xsl:value-of select="."/>
</xsl:template>


</xsl:stylesheet>
