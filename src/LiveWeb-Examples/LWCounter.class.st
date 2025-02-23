Class {
	#name : #LWCounter,
	#superclass : #LWComponent,
	#instVars : [
		'counter'
	],
	#category : #'LiveWeb-Examples'
}

{ #category : #accessing }
LWCounter >> counter: newCounterValue [
	counter := newCounterValue.
	self changed.
]

{ #category : #initialization }
LWCounter >> initialize [ 
	super initialize.
	counter := 0.

]

{ #category : #rendering }
LWCounter >> renderOn: h [
	h div: [ 
		h button: { #onclick -> [ self counter: counter + 1 ] } with: '+'.
		h div: counter.
		h button: { #onclick -> [ self counter: counter - 1 ] } with: '-'
	]
]
