//
//  Stream.swift
//  Swiftz
//
//  Created by Robert Widmann on 8/19/15.
//  Copyright © 2015 TypeLift. All rights reserved.
//

/// A lazy infinite sequence of values.
public struct Stream<T> {
	private let step : () -> (head : T, tail : Stream<T>)
	
	private init(_ step : () -> (head : T, tail : Stream<T>)) {
		self.step = step
	}
	
	/// Uses function to construct a `Stream`.
	///
	/// Unlike unfold for lists, unfolds to construct a `Stream` have no base case.
	public static func unfold<A>(initial : A, _ f : A -> (T, A)) -> Stream<T> {
		let (x, d) = f(initial)
		return Stream { (x, Stream.unfold(d, f)) }
	}
	
	/// Repeats a value into a constant stream of that same value.
	public static func `repeat`(x : T) -> Stream<T> {
		return Stream { (x, `repeat`(x)) }
	}
	
	/// Returns a `Stream` of an infinite number of iteratations of applications of a function to a value.
	public static func iterate(initial : T, _ f : T -> T)-> Stream<T> {
		return Stream { (initial, Stream.iterate(f(initial), f)) }
	}
	
	/// Cycles a non-empty list into an infinite `Stream` of repeating values.
	///
	/// This function is partial with respect to the empty list.
	public static func cycle(xs : [T]) -> Stream<T> {
		switch xs.match {
		case .Nil:
			return error("Cannot cycle an empty list.")
		case .Cons(let x, let xs):
			return Stream { (x, cycle(xs + [x])) }
		}
	}
	
	public subscript(n : UInt) -> T {
		return index(self)(n)
	}
	
	/// Looks up the nth element of a `Stream`.
	public func index<T>(s : Stream<T>) -> UInt -> T {
		return { n in
			if n == 0 {
				return s.step().head
			}
			return self.index(s.step().tail)(n - 1)
		}
	}
	
	/// Returns the first element of a `Stream`.
	public var head : T {
		return self.step().head
	}
	
	/// Returns the remaining elements of a `Stream`.
	public var tail : Stream<T> {
		return self.step().tail
	}
	
	/// Returns a `Stream` of all initial segments of a `Stream`.
	public var inits : Stream<[T]> {
		return Stream<[T]> { ([], self.step().tail.inits.fmap({ $0.cons(self.step().head) })) }
	}
	
	/// Returns a `Stream` of all final segments of a `Stream`.
	public var tails : Stream<Stream<T>> {
		return Stream<Stream<T>> { (self, self.step().tail.tails) }
	}
	
	/// Returns a pair of the first n elements and the remaining eleemnts in a `Stream`.
	public func splitAt(n : UInt) -> ([T], Stream<T>) {
		if n == 0 {
			return ([], self)
		}
		let (p, r) = self.tail.splitAt(n - 1)
		return (p.cons(self.head), r)
	}
	
	/// Returns the longest prefix of values in a `Stream` for which a predicate holds.
	public func takeWhile(p : T -> Bool) -> [T] {
		if p(self.step().head) {
			return self.step().tail.takeWhile(p).cons(self.step().head)
		}
		return []
	}
	
	/// Returns the longest suffix remaining after a predicate holds.
	public func dropWhile(p : T -> Bool) -> Stream<T> {
		if p(self.step().head) {
			return self.step().tail.dropWhile(p)
		}
		return self
	}
	
	/// Returns the first n elements of a `Stream`.
	public func take(n : UInt) -> [T] {
		if n == 0 {
			return []
		}
		return self.step().tail.take(n - 1).cons(self.step().head)
	}
	
	/// Returns a `Stream` with the first n elements removed.
	public func drop(n : UInt) -> Stream<T> {
		if n == 0 {
			return self
		}
		return self.step().tail.tail.drop(n - 1)
	}

	/// Removes elements from the `Stream` that do not satisfy a given predicate.
	///
	/// If there are no elements that satisfy this predicate this function will diverge.
	public func filter(p : T -> Bool) -> Stream<T> {
		if p(self.step().head) {
			return Stream { (self.step().head, self.step().tail.filter(p)) }
		}
		return self.step().tail.filter(p)
	}
	
	/// Returns a `Stream` of alternating elements from each Stream.
	public func interleaveWith(s2 : Stream<T>) -> Stream<T> {
		return Stream { (self.step().head, s2.interleaveWith(self.tail)) }
	}
	
	/// Creates a `Stream` alternating an element in between the values of another Stream.
	public func intersperse(x : T) -> Stream<T> {
		return Stream { (self.step().head, Stream { (x, self.step().tail.intersperse(x)) } ) }
	}

	/// Returns a `Stream` of successive reduced values.
	public func scanl<A>(initial : A, combine : A -> T -> A) -> Stream<A> {
		return Stream<A> { (initial, self.step().tail.scanl(combine(initial)(self.step().head), combine: combine)) }
	}

	/// Returns a `Stream` of successive reduced values.
	public func scanl1(f : T -> T -> T) -> Stream<T> {
		return self.step().tail.scanl(self.step().head, combine: f)
	}
}

/// Transposes the "Rows and Columns" of an infinite Stream.
public func transpose<T>(ss : Stream<Stream<T>>) -> Stream<Stream<T>> {
	let xs = ss.step().head
	let yss = ss.step().tail
	return Stream { (Stream { (xs.step().head, yss.fmap{ $0.head }) }, transpose(Stream { (xs.step().tail, yss.fmap{ $0.tail }) } )) }
}

/// Zips two `Stream`s into a third Stream using a combining function.
public func zipWith<A, B, C>(f : A -> B -> C) -> Stream<A> -> Stream<B> -> Stream<C> {
	return { s1 in { s2 in Stream { (f(s1.step().head)(s2.step().head), zipWith(f)(s1.step().tail)(s2.step().tail)) } } }
}

/// Unzips a `Stream` of pairs into a pair of Streams.
public func unzip<A, B>(sp : Stream<(A, B)>) -> (Stream<A>, Stream<B>) {
	return (sp.fmap(fst), sp.fmap(snd))
}

extension Stream : Functor {
	public typealias A = T
	public typealias B = Swift.Any
	public typealias FB = Stream<B>
	
	public func fmap<B>(f : A -> B) -> Stream<B> {
		return Stream<B> { (f(self.step().head), self.step().tail.fmap(f)) }
	}
}

public func <^> <A, B>(f : A -> B, b : Stream<A>) -> Stream<B> {
	return b.fmap(f)
}

extension Stream : Pointed {
	public static func pure(x : A) -> Stream<A> {
		return `repeat`(x)
	}
}

extension Stream : Applicative {
	public typealias FAB = Stream<A -> B>
	
	public func ap<B>(fab : Stream<A -> B>) -> Stream<B> {
		let f = fab.step().head
		let fs = fab.step().tail
		let x = self.step().head
		let xss = self.step().tail
		return Stream<B> { (f(x), (fs <*> xss)) }
	}
}

public func <*> <A, B>(f : Stream<A -> B> , o : Stream<A>) -> Stream<B> {
	return o.ap(f)
}

extension Stream : Monad {
	public func bind<B>(f : A -> Stream<B>) -> Stream<B> {
		return Stream<B>.unfold(self.fmap(f)) { ss in
			let bs = ss.step().head
			let bss = ss.step().tail
			return (bs.head, bss.fmap({ $0.tail }))
		}
	}
}

public func >>- <A, B>(x : Stream<A>, f : A -> Stream<B>) -> Stream<B> {
	return x.bind(f)
}

extension Stream : Copointed {
	public func extract() -> A {
		return self.head
	}
}

extension Stream : Comonad {
	public typealias FFA = Stream<Stream<A>>
	
	public func duplicate() -> Stream<Stream<A>> {
		return self.tails
	}
	
	public func extend<B>(f : Stream<A> -> B) -> Stream<B> {
		return Stream<B> { (f(self), self.tail.extend(f)) }
	}
}

extension Stream : ArrayLiteralConvertible {
	public init(fromArray arr : [T]) {
		self = Stream.cycle(arr)
	}
	
	public init(arrayLiteral s : T...) {
		self.init(fromArray: s)
	}
}

public final class StreamGenerator<Element> : GeneratorType {
	var l : Stream<Element>
	
	public func next() -> Optional<Element> {
		let (hd, tl) = l.step()
		l = tl
		return hd
	}
	
	public init(_ l : Stream<Element>) {
		self.l = l
	}
}

extension Stream : SequenceType {
	public typealias Generator = StreamGenerator<T>
	
	public func generate() -> StreamGenerator<T> {
		return StreamGenerator(self)
	}
}

extension Stream : CollectionType {
	public typealias Index = UInt
	
	public var startIndex : UInt { return 0 }
	
	public var endIndex : UInt {
		return error("An infinite list has no end index.")
	}
}

extension Stream : CustomStringConvertible {
	public var description : String {
		return "[\(self.head), ...]"
	}
}
