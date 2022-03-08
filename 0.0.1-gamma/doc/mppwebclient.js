//create onDomReady Event
window.onDomReady = DomReady;

//Setup the event
function DomReady(fn)
{
        //W3C
        if(document.addEventListener)
        {
                document.addEventListener("DOMContentLoaded", fn, false);
        }
        //IE
        else
        {
                document.onreadystatechange = function(){readyState(fn)}
        }
}

//IE execute function
function readyState(fn)
{
        //dom is ready for interaction
        if(document.readyState == "interactive")
        {
                fn();
        }
}

function toggle(t,eid) {
    if (!t) { return; }
    var elms = t.getElementsByTagName("*");
    for (var i=0, maxI=elms.length; i<maxI; ++i) {
        var elm = elms[i];
        if (elm.id === eid) {
            if (elm.style.display == 'none') {
                elm.style.display = 'inline';
            } else {
                elm.style.display = 'none';
            }
        }
    }
}

function toggletext(t,tx1,tx2) {
    if (t.innerHTML === tx2) {
        t.innerHTML = tx1;
    } else {
        t.innerHTML = tx2;
    }
}

function replaceobj(http,jsonRequestText)
{
  var url = "/mpp-client/objup";
  var par = ("json=" + jsonRequestText);
  http.open("POST", url, true);
  http.setRequestHeader("Content-type", "application/x-www-form-urlencoded");
  http.setRequestHeader("Content-length", par.length);
  http.setRequestHeader("Connection", "close");
  http.onreadystatechange=function() {
    if(http.readyState == 4) {
        if(http.status != 200) {
            alert("Error getting updates!")
        }
      // alert("Response: "+http.responseText);
      var navLUTelm = document.getElementById('NavLastUpdateTime');
      if (navLUTelm) {
          var d = new Date();
          navLUTelm.innerHTML = d.toLocaleString();
      }
      var jsonResponseObject = eval('(' + http.responseText + ')');
      for ( var objid in jsonResponseObject ) {
          if( objid === "undefined" ){
              continue;
          } else if( jsonResponseObject[objid] === "undefined" ){
              continue;
          } else {
              var elm = document.getElementById(objid);
              if (elm) {
                  elm.innerHTML = jsonResponseObject[objid];
              }
          }
      }
    }
  }
  http.send(par);
}

