Class {
	#name : #LWExampleStyles,
	#superclass : #LWStylesheetProvider,
	#category : #'LiveWeb-Examples'
}

{ #category : #'as yet unclassified' }
LWExampleStyles >> centeredDialog [ 
	^ self style: [ :s |
		s display: 'flex'; position: 'fixed';
       alignItems:'center'; justifyContent: 'center'; textAlign: 'center';
			fontSize: 5 rem;
			left: 25vw; top: 25vh;
			width: 50vw; height: 50vh;
			zIndex: 100;
			border: 'solid 5px black'; borderRadius: 0.5em;
			backgroundColor: 'gray' ]
]

{ #category : #'as yet unclassified' }
LWExampleStyles >> clockFace [ 
	^ self style: [:s | s strokeWidth: 2px; stroke: 'wheat' ]
]

{ #category : #'as yet unclassified' }
LWExampleStyles >> clockHands [
	^ self style: [ :s | s strokeWidth: 1px; fill: '#333'; stroke: '#555']

]

{ #category : #'as yet unclassified' }
LWExampleStyles >> flexCol: s [
	s display: 'flex'; flexDirection: 'column'.

]

{ #category : #'as yet unclassified' }
LWExampleStyles >> flexRow: s [
	s display: 'flex'; flexDirection: 'row'.

]

{ #category : #initialization }
LWExampleStyles >> initialize [
	super initialize
]

{ #category : #'as yet unclassified' }
LWExampleStyles >> wordleGame [
	"Style for the main element"
	^ self style: [ :s | self flexCol: s ]
]

{ #category : #'as yet unclassified' }
LWExampleStyles >> wordleGuess [ 
	^ self style: [ :s | 
		self flexRow: s. 
		s flexWrap: 'nowrap'
	]
]

{ #category : #'as yet unclassified' }
LWExampleStyles >> wordleGuessCharacter: inPosition word: inWord [
	^ self style: [ :s |
		self wordleKey: s.
		inPosition 
			ifTrue: [ s backgroundColor: 'green' ]
			ifFalse: [ inWord ifTrue: [ s backgroundColor: 'yellow' ] ] ]
		named: 'wch'
]

{ #category : #'as yet unclassified' }
LWExampleStyles >> wordleKey: s [
  s display: 'block'; 
    width: 7vw; height: 7vh; margin: 2px; 
    fontSize: 5.5vh; fontFamily:'sans-serif'; textTransform: 'capitalize'; textAlign:'center';
    border: 'solid 0.5vw black'; borderRadius: 2vw;
    cursor: 'pointer'

]

{ #category : #'as yet unclassified' }
LWExampleStyles >> wordleKeyboard [
	^ self style: [ :s | self flexCol: s ]
]

{ #category : #'as yet unclassified' }
LWExampleStyles >> wordleKeyboardKey: disabled [
	^ self style: [ :s | 
		self wordleKey: s.
		disabled ifTrue: [ s backgroundColor: 'darkGray' ]
		]
		named: 'k'
]

{ #category : #'as yet unclassified' }
LWExampleStyles >> wordleKeyboardRow [
	^ self style: [ :s | self flexRow: s. s flexWrap:'nowrap'; height: 11vh ] named: 'kb'
]