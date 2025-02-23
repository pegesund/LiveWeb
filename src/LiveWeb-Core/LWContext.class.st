"
I provide a context for the client's instance of a component tree.
I keep track of all the components and their ids and callbacks.

I also provide user objects that can be used to provide additional information to components. 
"
Class {
	#name : #LWContext,
	#superclass : #Object,
	#instVars : [
		'nextId',
		'connection',
		'callbacks',
		'callbackIdsByComponent',
		'components',
		'user',
		'sendQueue',
		'page'
	],
	#category : #'LiveWeb-Core'
}

{ #category : #accessing }
LWContext >> at: aKey [
	"Get the user object at key or nil."
	^ user at: aKey ifAbsent: nil
]

{ #category : #accessing }
LWContext >> at: aKey put: userObject [
	"Put a user object into context."
	user at: aKey put: userObject
]

{ #category : #accessing }
LWContext >> callbackFor: id [
	^ callbacks at: id ifAbsent: nil
]

{ #category : #cleaning }
LWContext >> cleanup: component [
  "do state cleanup for component before rerender (does not unmount)"
 self cleanup: component unmount: false
]

{ #category : #cleaning }
LWContext >> cleanup: component unmount: unmount [
  "do state cleanup for component before rerender"
  [ component childrenRecursive do: [:c |  self cleanupComponent: c unmount: unmount ].
  self cleanupComponent: component unmount: false ] on: Error do: [:sig |  LWLogEvent warn: 'Cleanup exception for ' , component printString , ' signal: ' , sig printString ]
]

{ #category : #cleaning }
LWContext >> cleanupComponent: c unmount: shouldUnmount [
  | callbackIds |
  c isMounted ifFalse: [ ^self ].
  shouldUnmount ifTrue: [ c doUnmount ].
  callbackIds := callbackIdsByComponent removeKey: c id ifAbsent: #().
  callbackIds do: [:id |  callbacks removeKey: id ]
]

{ #category : #'component lifecycle' }
LWContext >> component: parentComponent childAdded: newChildComponent at: index [
	"notify that a child was added to an already mounted parent component.
	Will mount and render the child and send it to the client, adding it
	to the page DOM at the right position."
	connection component: parentComponent childAdded: newChildComponent at: index.
]

{ #category : #accessing }
LWContext >> components [

	^ components
]

{ #category : #accessing }
LWContext >> connection [

	^ connection
]

{ #category : #accessing }
LWContext >> connection: anObject [
	connection := anObject.
	sendQueue ifNotNil: [ 
		connection send: sendQueue asArray.
		sendQueue := nil.
  ]
]

{ #category : #cleaning }
LWContext >> connectionClosed [
	connection := nil.
	components valuesDo: [ :c | self cleanup: c unmount: true ]. 
	components := nil.
]

{ #category : #'client control' }
LWContext >> go: aPushState [
	"Send push state navigation to client.
	The push state must be a LWPushStateBase subclass or compatible that
	knows how to create the route path and JSON state."
	| state route |
	state := aPushState asPushStateJSON.
	route := aPushState asRoute.
	self send: 'E' for: '' with: ('_lw.pushState(<1s>, <2s>)'
		expandMacrosWith: (STON toJsonString: state)
		 with: (STON toJsonString: route)).
		
	"Also notify page that push state has changed (so it can update any components)"
	page pushStateChanged: state.
]

{ #category : #'client control' }
LWContext >> go: path with: state [
	"Send push state navigation to client with given state (must be convertable to JSON).
	This will only work if page is using push state. 
	State should contain everything needed to reconstitute the parameters of the 
	page, as they will be sent back by the browser when user navigates (eg. back/forward button)."
	self send: 'E' for: '' with: ('_lw.pushState(<1s>, <2s>)'
		expandMacrosWith: (STON toJsonString: state)
		 with: (STON toJsonString: path)).
		
	"Also notify page that push state has changed (so it can update any components)"
	page pushStateChanged: state.
]

{ #category : #'client control' }
LWContext >> goJS: aPushState [
	"Return JS callback that navigates with push state when invoked.
	The callback will prevent default click handler so it can be used in HTML anchor links."
	^ LWScriptCallback new 
			callback: [ self go: aPushState ]; 
			jsParams: #(); 
			preventDefault: true.
			
]

{ #category : #'client control' }
LWContext >> goJS: path with: state [
	"Return JS callback that navigates with push state using (go:with:).
	The callback will prevent default click handler so it can be used in HTML anchor links."
	^ LWScriptCallback new 
			callback: [ self go: path with: state ]; 
			jsParams: #(); 
			preventDefault: true.
			
]

{ #category : #initialization }
LWContext >> initialize [
	nextId := 0.
	user := Dictionary new.
]

{ #category : #accessing }
LWContext >> nextComponentId [
	| id |
	id := nextId.
	nextId := nextId + 1.
	^ id
]

{ #category : #accessing }
LWContext >> page [ 
	"return the page I am the context for"
	^ page
]

{ #category : #accessing }
LWContext >> page: aPage [
	"set the page I am the context for"
	page := aPage
]

{ #category : #registering }
LWContext >> registerCallback: aBlock for: component [
   "register callback, returns id number of callback"
	| id |
	id := self nextComponentId .
	callbacks ifNil: [ 
		callbacks := Dictionary new. 
		callbackIdsByComponent := Dictionary new.
		].
	callbacks at: id put: aBlock.
	callbackIdsByComponent at: component id update: [ :ids | ids add: id; yourself ] initial: [Bag with: id].
	^ id
]

{ #category : #registering }
LWContext >> registerComponent: anLWComponent [
   "register new component in this context, returns id number of component"
	| id |
	id := self nextComponentId .
	components ifNil: [ components := Dictionary new. ].
	components at: id put: anLWComponent.
	^ id
]

{ #category : #'component lifecycle' }
LWContext >> rerenderComponent: component [
	"notify that some component in the tree has changed and needs rerender"
	connection 
		ifNil: [ 
			"PENDING: handle separate cases: page not YET connected and connection going away"
			component unmount ]
		ifNotNil: [ 	connection rerenderComponent: component ]
]

{ #category : #'client control' }
LWContext >> send: patchType for: componentId with: content [
	"Send patch for component with content.
	If connection is not yet established, the send will be queued."
	connection
	  ifNil: [
			sendQueue ifNil: [ sendQueue := OrderedCollection new ].
			sendQueue add: { componentId asString . patchType asString . content }
		]
	  ifNotNil: [ connection send: { { componentId asString. patchType asString. content } } ] 
]

{ #category : #testing }
LWContext >> used [ 
	"has this context been used to generate any live components or callbacks?"
	^ nextId > 0
]
