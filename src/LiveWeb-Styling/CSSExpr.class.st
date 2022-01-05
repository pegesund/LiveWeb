Class {
	#name : #CSSExpr,
	#superclass : #Object,
	#category : #'LiveWeb-Styling'
}

{ #category : #arithmetic }
CSSExpr >> * expr [
	^ self calc: '*' with: expr
]

{ #category : #arithmetic }
CSSExpr >> + expr [
  ^ self calc: '+' with: expr
]

{ #category : #arithmetic }
CSSExpr >> - expr [
	^ self calc: '-' with: expr
]

{ #category : #arithmetic }
CSSExpr >> / expr [
	^ self calc: '/' with: expr
]

{ #category : #accessing }
CSSExpr >> asCSSPropertyValue [
	^ self subclassResponsibility
]

{ #category : #accessing }
CSSExpr >> asCSSPropertyValueNested [
	^ self asCSSPropertyValue 
]

{ #category : #'as yet unclassified' }
CSSExpr >> calc: op with: right [
	(right respondsTo: #asCSSPropertyValue) ifFalse: [ Error new signal: 'Only CSS expressions can be calc''d.' ].
	^ CSSBinaryExpr new 
		op: op;
		left: self; 
		right: right
]

{ #category : #testing }
CSSExpr >> isCSSCalculated [
	^ false
]