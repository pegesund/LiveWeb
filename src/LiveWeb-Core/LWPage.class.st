"
I represent a page in a web application. 

The page is the main HTTP endpoint, and will respond with a full HTML page that includes
scripts required to setup live interaction.

The page subclass is responsible for creating the body component.
The page can optionally have a head component that can be used to inject other 
resources (like CSS and fonts).

"
Class {
	#name : #LWPage,
	#superclass : #Object,
	#instVars : [
		'ctx',
		'id',
		'args',
		'head',
		'body'
	],
	#classVars : [
		'currentPages'
	],
	#category : #'LiveWeb-Core'
}

{ #category : #'as yet unclassified' }
LWPage class >> clientConnectionScript [ 
	"Get a client connection script. 
	Initially copied from ripley project."
	^ 'window._lw = {
    connection: null,
    debug: false,
    preOpenQueue: [],
    type: "ws",
    connected: false,
    debounceTimeout: {},
    get: function(id) {
        return document.querySelector("[data-lw=''"+id+"'']");
    },
    send: function(id, args, debouncems) {
        if(this.debug) console.log("Sending id:", id, ", args: ", args);
        if(!this.connected) {
            this.preOpenQueue.push({id: id, args: args});
        } else {
            if(debouncems === undefined) {
                this._send(id,args);
            } else {
                var tid = this.debounceTimeout[id];
                if(tid !== undefined) {
                    window.clearTimeout(tid);
                }
                this.debounceTimeout[id] = window.setTimeout(
                    function() { _lw._send(id,args); },
                    debouncems
                );
            }
        }
    },
    _send: function(id,args) {
        if(this.type === "sse") {
            var l = window.location;
            fetch(l.protocol+"//"+l.host+this.cpath+"?id="+this.cid,
                  {method: "POST",
                   headers: {"Content-Type":"application/json"},
                   body: JSON.stringify([id].concat(args))})
        } else if(this.type === "ws") {
            let msg = id+":"+JSON.stringify(args);
            this.connection.send(msg);
        } else {
            console.err("Unknown connection type: ", this.type);
        }
    },
    onopen: function(e) {
        this.connected = true;
        let q = this.preOpenQueue;
        let c = this.connection;
        for(var i = 0; i<q.length; i++) {
            let cb = q[i];
            this.send(cb.id, cb.args);
        }
        // clear the array
        q.length = 0;
    },
    connect: function(path, id) {
        var l = window.location;
        if(this.type === "sse") {
            var url = l.protocol+"//"+l.host+path+"?id="+id;
            this.connection = new EventSource(url, {withCredentials:true});
            this.connection.onmessage = this.onmessage.bind(this);
            this.cid = id;
            this.cpath = path;
            this.connection.onopen = this.onopen.bind(this);
        } else if(this.type === "ws") {
            var url = (l.protocol=="https:"?"wss://":"ws://")+l.host+path+"?id="+id;
            this.connection = new WebSocket(url);
            this.connection.onmessage = this.onmessage.bind(this);
            this.connection.onopen = this.onopen.bind(this);
            this.connection.onclose = this.onclose.bind(this);
        } else {
            console.error("Unknown connection type: ", this.type);
        }
    },
    setAttr: function(elt, attr, value) {
        // set attributes, some are set as properties instead
        if(attr === "checked") {
            elt.checked = value!==null;
        } else if(elt.tagName === "INPUT" && attr === "value") {
            elt.value = value;
        } else if(attr === "class" && elt.hasAttribute("data-rl-class")) {
            // has static class + dynamic part
            elt.className = elt.getAttribute("data-rl-class") + " " + value;
        } else {
            if(value === null) {
                elt.removeAttribute(attr);
            } else {
                elt.setAttribute(attr,value);
            }
        }
    },
    onmessage: function(msg) {
        if(this.debug) console.log("Received:", msg);
        if(msg.data === "!") {
            // Appliation level PING
            this.connection.send("!");
        } else {
            var patches = JSON.parse(msg.data);
            var patchlen = patches.length;
            for(var p = 0; p < patchlen; p++) {
                var patch = patches[p];
                var id = patch[0];
                var elt = (id === "" && patch[1] === "E") ? document : _lw.get(id);
                if(elt == null) {
                    console.error("Received content for non-existant element: ", id,
                                  "msg:", msg);
                } else {
                    var method = patch[1];
                    var payload = patch[2];
                    if(this.debug) console.log("elt: ", elt, "method: ", method, ", payload: ", payload);
                    switch(method) {  
                       case "R": _lw.R(elt,payload); break;
                       case "A": elt.innerHTML += payload; break;
                       case "P": elt.innerHTML = payload + elt.innerHTML; break;
                       case "D": elt.parentElement.removeChild(elt); break;
                       case "F": elt.insertAdjacentHTML("afterend",payload); break;
                       case "M": elt.insertAdjacentElement("afterend",_lw.get(payload)); break;
                       case "<": elt.parentElement.insertAdjacentElement("afterbegin",elt); break;
                       case ">": elt.parentElement.insertAdjacentElement("beforeend",elt); break;
                       case "@": for(var attr in payload) { _lw.setAttr(elt, attr, payload[attr]) }; break;
                       case "E": (new Function(payload)).call(elt); break;
                       case "+": /* add child at index */
                           elt.insertBefore(patch[3], elt.childNodes[patch[2]]); break;
                       case "H": /* flasH an animation class */
                           _lw.flash(elt,payload); break;
                       case "+C": /* add class */
                           elt.classList.add(payload); break;
                       case "-C": /* remove class */
                           elt.classList.remove(payload); break;
                       case "T": /* render from template to target id */
                           _lw.T(elt,payload[0],payload[1]); break;
                    }
                }
            }
        }
    },
    onclose: function(evt) {
        // PENDING: reconnect needs server to not cleanup the connection
        // other solution is to reload page (should do only if reconnect
        // fails because server has discarded the live context)
        console.log("WebSocket connection closed", evt);

        // If application has added an global function with name "liveweb_disconnected"
        // then call that.
        let disconnected = window.liveweb_disconnected;
        if(typeof(disconnected) === "function") {
            disconnected();
        }
    },

    // helper for R patch method to work around SVG issues
    // PENDING: need similar fix for appends? try to generalize
    R: function(elt, withContent) {
        if(elt.namespaceURI === "http://www.w3.org/2000/svg") {
            // Some browsers (Safari at least) can''t use outerHTML
            // replace as method to patch SVG.
            var parent = elt.parentElement;
            var g = document.createElementNS(parent.namespaceURI, parent.tagName);
            g.innerHTML = withContent;
            elt.replaceWith(g.firstElementChild);
        } else {
            // Simple outerHTML change for HTML elements
            elt.outerHTML = withContent;
        }
        // if there were any scripts in the replaced content, evaluate them
        // we need to refetch the element from DOM after its outerHTML changd
        if(withContent.match(/<script/ig)) {   
			   let id = elt.getAttribute("data-lw");
            _lw.get(id).querySelectorAll("script").forEach( (script) => {
					if(script.getAttribute("type") != "liveweb/placeholder") {  
	                eval(script.text+"")
					}
            })
        }
    },
    T: function(templateElt, targetEltId, data) { 
		 let target = document.getElementById(targetEltId);
		 target.textContent="";
		 for(let i=0;i<data.length;i++) {
		   let n = document.importNode(templateElt.content,true).firstChild;
		   n.classList.add("templateItem"+(i%2==0?"Even":"Odd"));
			n.getAttributeNames().forEach(a => { 
			  let v = n.getAttribute(a);
			  if(typeof(v) === "string" && v.startsWith("_lw_slot:")) { 
			    n.setAttribute(a, data[i][parseInt(v.substring(9))]);
			  }
			});
			n.querySelectorAll("slot").forEach(s => { 
			  s.outerText = data[i][parseInt(s.name)];
			});
			target.appendChild(n);
		 };
    },
    flash: function(elt, className) { 
      // add animationend handler if needed
      if(!elt.hasAttribute("data-lw-flashhandler")) { 
        elt.addEventListener("animationend", (e) => { 
          console.log("animation ended, remove the class");
          e.target.classList.remove(e.target.getAttribute("data-lw-flash"));
        });
        elt.setAttribute("data-lw-flashhandler", "1");
      }
      elt.setAttribute("data-lw-flash", className);
      elt.classList.add(className);
    },
    pushState: function(state, location) { 
      let l = window.location;
      window.history.pushState({s:state}, "", l.protocol+"//"+l.host+location);
    },
    enablePushState: function(initialState, callbackId) { 
      pushStateCallbackId = callbackId;
 		 history.replaceState({s:initialState},document.title);
		 window.addEventListener("popstate", (s) => _lw.send(callbackId, [s.state.s]));
    }
}

_lws = _lw.send.bind(_lw)
'
]

{ #category : #testing }
LWPage class >> designatedMimeType [ 
	^ nil

]

{ #category : #'instance creation' }
LWPage class >> for: aUUID [
	"get rendered page for given id"
	^ currentPages ifNil: nil ifNotNil: [ 
		currentPages at: aUUID ifAbsent: nil ]
]

{ #category : #'as yet unclassified' }
LWPage class >> registerPage: aPageInstance for: aUUID [
	currentPages ifNil: [ currentPages := Dictionary new. ].
	currentPages at: aUUID put: aPageInstance.
]

{ #category : #'as yet unclassified' }
LWPage class >> unregisterPage: uuid [
	"should unmount any components left over?"
	currentPages removeKey: uuid.
]

{ #category : #accessing }
LWPage >> args [
	"answer with the arguments for this page"
	^ args
]

{ #category : #'API - accessing' }
LWPage >> body: args [
	"create the body LWComponent"
	SubclassResponsibility new signal: 'LWPage subclasses must implement body'
]

{ #category : #accessing }
LWPage >> ctx [

	^ ctx
]

{ #category : #testing }
LWPage >> designatedMimeType [ 
	^ nil

]

{ #category : #'API - accessing' }
LWPage >> head: args [
	"create the head LWComponent, by default returns nil"
	^ nil
]

{ #category : #'as yet unclassified' }
LWPage >> htmlRenderer: stream [
	^ HTMLRenderer on: stream
]

{ #category : #accessing }
LWPage >> id [

	^ id
]

{ #category : #'push state handling' }
LWPage >> initialPushState [
	"Get the initial pushState when the page is rendered. Must be serializable as JSON."
	self subclassResponsibility 

]

{ #category : #testing }
LWPage >> isEmpty [
	^ false
]

{ #category : #'as yet unclassified' }
LWPage >> prepareCtx [ 
	"Prepare context before page is being rendered.
	Called after ctx and args instance variables have been set."
]

{ #category : #'push state handling' }
LWPage >> pushStateChanged: newPushState [
	"Update component state based on new push state received from client."
	self subclassResponsibility 

]

{ #category : #'as yet unclassified' }
LWPage >> readArguments: aZnRequest [
	"read incoming HTTP arguments that will be passed to head: and body: calls.
	By default returns the request as is."
	^ aZnRequest 
]

{ #category : #'push state handling' }
LWPage >> usePushState [
	"If true, subclass must handle updating state based on received popped navigation state by the browser.
	Push state is handled by rendering a script that will invoke a callback when the server state is 
	popped.
	Subclasses using must also override initialPushState to return the initial state when the page
	is first rendered (should use any arguments or path to determine it). The state is serialized as JSON.
	 
	If false, no scripts to handle pushState in the client will be rendered."
	^ false
]

{ #category : #accessing }
LWPage >> value: req [
	| content |
	[ 
	id := UUIDGenerator next. 
	ctx := LWContext new.
	ctx page: self.
	args := self readArguments: req.
	self prepareCtx .
	content := String streamContents: [:out | self writeOn: out ].
	^ ZnResponse ok: (ZnStringEntity new string: content; contentType: 'text/html; charset=UTF-8')
	] on: Error 
     do: [ :err | 
		LWLogEvent error: 'Error rendering page: ', self printString, ' error: ', err printString.  
		err debug.
		^ ZnResponse serverError: 'Internal server error, see log for details.'
	].
	
]

{ #category : #writing }
LWPage >> writeOn: stream [
	| h pushStateScript |
	head := self head: args.
	body := self body: args.
	self usePushState ifTrue: [ pushStateScript := LWPushState on: self ].
	stream nextPutAll: '<!doctype html>'; nextPut: Character lf.
	h := self htmlRenderer: stream.
	h ctx: ctx.
	h html: 
	[ h head: [ 
		pushStateScript ifNotNil: [
			pushStateScript inContext: ctx.
			pushStateScript render: h ].
		head ifNotNil: [ 
			head inContext: ctx.
			head render: h ].
	   ].
     h body: [ 
		body inContext: ctx.
		body render: h.
		
		ctx used ifTrue: [ 
			"if body render did cause some live elements, output connection script
			and register this page"
 			self class registerPage: self for: id. 
			h script: [ h raw: (self class clientConnectionScript, '
				document.onload = _lw.connect("/__liveweb", "', id asString  ,'")') ].
		]
	 ]
   ].

	stream close.

]
