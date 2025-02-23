Class {
	#name : #LWExampleMenu,
	#superclass : #LWStyledComponent,
	#instVars : [
		'active'
	],
	#category : #'LiveWeb-Examples'
}

{ #category : #accessing }
LWExampleMenu >> active: activeItem [
	active := activeItem.
	self changed.
]

{ #category : #'as yet unclassified' }
LWExampleMenu >> menu: h link: exampleName titled: titleText [
  | activeItem |
  activeItem := active = exampleName.
	h div: { self style menuLink: activeItem } with: [ 
		| location |
		location := '/examples/',exampleName.
		h a: { #href -> location. #onclick -> (ctx goJS: location with: { #example -> exampleName } asDictionary) } with: titleText
  ]
]

{ #category : #rendering }
LWExampleMenu >> renderOn: h [
	h div: { self style menu } with: [
			self menu: h link: 'counter' titled: 'Counter'.
			self menu: h link: 'multi-counter' titled: 'Multi counter'.
			self menu: h link: 'wordle' titled: 'Wordle'.
			self menu: h link: 'clock' titled: 'Clock'.
			self menu: h link: 'typeahead' titled: 'Typeahead'.
		].
]
