[![W3C](https://www.w3.org/Icons/w3c_home)](https://www.w3.org/)

# Efficient XML Interchange (EXI) Format 1.0 (Second Edition)

## W3C Recommendation 11 February 2014

This version:
:   [http://www.w3.org/TR/2014/REC-exi-20140211/](https://www.w3.org/TR/2014/REC-exi-20140211/)

Latest version:
:   [http://www.w3.org/TR/exi/](https://www.w3.org/TR/exi/)

Previous version:
:   [http://www.w3.org/TR/2013/PER-exi-20131022/](https://www.w3.org/TR/2013/PER-exi-20131022/)

Editors:
:   John Schneider, AgileDelta, Inc. (First Edition)
:   Takuki Kamiya, Fujitsu Laboratories of America, Inc. (First Edition)
:   Daniel Peintner, Siemens AG (Second Edition)
:   Rumen Kyusakov, Invited Expert, Luleå University of Technology (Second Edition)

Please check the
[**errata**](https://www.w3.org/XML/EXI/exi-10b-errata)
for any errors or issues reported since
publication.

See also [**translations**](https://www.w3.org/TR/2014/REC-exi-20140211/%2Ctranslations).

[Copyright](https://www.w3.org/Consortium/Legal/ipr-notice#Copyright) © 2014 [W3C](https://www.w3.org/)® ([MIT](http://www.csail.mit.edu/), [ERCIM](http://www.ercim.org/), [Keio](http://www.keio.ac.jp/), [Beihang](http://ev.buaa.edu.cn/)), All Rights Reserved. W3C [liability](https://www.w3.org/Consortium/Legal/ipr-notice#Legal_Disclaimer), [trademark](https://www.w3.org/Consortium/Legal/ipr-notice#W3C_Trademarks) and [document use](https://www.w3.org/Consortium/Legal/copyright-documents) rules apply.

---

## Abstract

This document is the specification of the Efficient XML Interchange (EXI)
format. EXI is a very compact representation for the Extensible Markup
Language (XML) Information Set that is intended to simultaneously optimize
performance and the utilization of computational resources. The EXI
format uses a hybrid approach drawn from the information and formal language
theories, plus practical techniques verified by measurements,
for entropy encoding XML information. Using a relatively simple algorithm,
which is amenable to fast and compact implementation, and a small set of
datatype representations,
it reliably produces efficient encodings of XML event streams.
The grammar production system and format definition of EXI are presented.

## Status of this Document

*This section describes the status of this document at the time
of its publication. Other documents may supersede this document. A
list of current W3C publications and the latest revision of this
technical report can be found in the [W3C technical reports index](https://www.w3.org/TR/) at http://www.w3.org/TR/.*

This is the Second Edition Recommendation of the Efficient XML Interchange Format 1.0.
The Second Edition incorporates a number of corrections that were published as
[errata](https://www.w3.org/XML/EXI/exi-10-errata)
against the First Edition, as well as other changes that help make the specification more readable and unambiguous.
It has been produced by the [EXI Working Group](https://www.w3.org/XML/EXI/), which is part of the [Extensible Markup Language (XML) Activity](https://www.w3.org/XML/Activity).
The goals of the EXI Working Group are discussed in the [charter](https://www.w3.org/XML/2009/02/exi-charter.html).

Changes since the First Edition Recommendation are listed in the [Change Log](#changes). A [diff-marked version](https://www.w3.org/2007/10/htmldiff?doc1=http://www.w3.org/TR/2011/REC-exi-20110310/&doc2=http://www.w3.org/TR/2014/REC-exi-20140211/) against the previous version of this document is also available.

The EXI Working Group has produced a
[test suite](https://www.w3.org/XML/EXI/#InteropTestingFramework) testing the interoperability of this specification, and an [interoperability test report](https://www.w3.org/XML/EXI/implementation-report/EXI_1_0_2nd_Edition.html).

This document has been reviewed by W3C Members, by software developers, and by other W3C groups and interested parties, and is endorsed by the Director as a W3C Recommendation. It is a stable document and may be used as reference material or cited from another document. W3C's role in making the Recommendation is to draw attention to the specification and to promote its widespread deployment. This enhances the functionality and interoperability of the Web.

Individuals are invited to send feedback on this document by email to public-exi-comments@w3.org, a mailing list with a [public archive](http://lists.w3.org/Archives/Public/public-exi-comments/). This mailing list is reserved for comments, it is inappropriate to send discussion email to this address. Discussion should take place on the public-exi@w3.org mailing list ([public archive](http://lists.w3.org/Archives/Public/public-exi/)).

This document was produced by a group operating under the [5 February 2004 W3C Patent Policy](https://www.w3.org/Consortium/Patent-Policy-20040205/). W3C maintains a [public list of any patent disclosures](https://www.w3.org/2004/01/pp-impl/38502/status#specs) made in connection with the deliverables of the group; that page also includes instructions for disclosing a patent.

## Table of Contents

1. [Introduction](#introduction)
    1.1 [History and Design](#history)
    1.2 [Notational Conventions and Terminology](#conventions)
2. [Design Principles](#principles)
3. [Basic Concepts](#concepts)
4. [EXI Streams](#streams)
5. [EXI Header](#header)
    5.1 [EXI Cookie](#EXICookie)
    5.2 [Distinguishing Bits](#DistinguishingBits)
    5.3 [EXI Format Version](#version)
    5.4 [EXI Options](#options)
6. [Encoding EXI Streams](#encodingEvents)
    6.1 [Determining Event Codes](#eventCodes)
    6.2 [Representing Event Codes](#encodingEventCodes)
    6.3 [Fidelity Options](#fidelityOptions)
7. [Representing Event Content](#encodingValues)
    7.1 [Built-in EXI Datatype Representations](#encodingDatatypes)
        7.1.1 [Binary](#encodingBinary)
        7.1.2 [Boolean](#encodingBoolean)
        7.1.3 [Decimal](#encodingDecimal)
        7.1.4 [Float](#encodingFloat)
        7.1.5 [Integer](#encodingInteger)
        7.1.6 [Unsigned Integer](#encodingUnsignedInteger)
        7.1.7 [QName](#encodingQName)
        7.1.8 [Date-Time](#encodingDateTime)
        7.1.9 [n-bit Unsigned Integer](#encodingBoundedUnsigned)
        7.1.10 [String](#encodingString)
            7.1.10.1 [Restricted Character Sets](#restrictedCharSet)
        7.1.11 [List](#encodingList)
    7.2 [Enumerations](#encodingEnumerations)
    7.3 [String Table](#stringTable)
        7.3.1 [String Table Partitions](#stringTablePartitions)
        7.3.2 [Partitions Optimized for Frequent use of Compact Identifiers](#encodingOptimizedForHits)
        7.3.3 [Partitions Optimized for Frequent use of String Literals](#encodingOptimizedForMisses)
    7.4 [Datatype Representation Map](#datatypeRepresentationMap)
8. [EXI Grammars](#grammars)
    8.1 [Grammar Notation](#grammarNotation)
        8.1.1 [Fixed Event Codes](#fixedEventCodes)
        8.1.2 [Variable Event Codes](#variableEventCodes)
    8.2 [Grammar Event Codes](#grammarEventCodes)
    8.3 [Pruning Unneeded Productions](#pruningProductions)
    8.4 [Built-in XML Grammars](#builtinGrammars)
        8.4.1 [Built-in Document Grammar](#builtinDocGrammars)
        8.4.2 [Built-in Fragment Grammar](#builtinFragGrammars)
        8.4.3 [Built-in Element Grammar](#builtinElemGrammars)
    8.5 [Schema-informed Grammars](#informedGrammars)
        8.5.1 [Schema-informed Document Grammar](#informedDocGrammars)
        8.5.2 [Schema-informed Fragment Grammar](#informedFragGrammars)
        8.5.3 [Schema-informed Element Fragment Grammar](#informedElementFragGrammar)
        8.5.4 [Schema-informed Element and Type Grammars](#informedElemGrammars)
            8.5.4.1 [EXI Proto-Grammars](#protoGrammars)
                8.5.4.1.1 [Grammar Concatenation Operator](#grammarConcatOperator)
                8.5.4.1.2 [Element Grammars](#elementGrammars)
                8.5.4.1.3 [Type Grammars](#typeGrammars)
                    8.5.4.1.3.1 [Simple Type Grammars](#simpleTypeGrammars)
                    8.5.4.1.3.2 [Complex Type Grammars](#complexTypeGrammars)
                8.5.4.1.4 [Attribute Uses](#attributeUses)
                8.5.4.1.5 [Particles](#particles)
                8.5.4.1.6 [Element Terms](#elementTerms)
                8.5.4.1.7 [Wildcard Terms](#wildcardTerms)
                8.5.4.1.8 [Model Group Terms](#modelGroupTerms)
                    8.5.4.1.8.1 [Sequence Model Groups](#sequenceGroupTerms)
                    8.5.4.1.8.2 [Choice Model Groups](#choiceGroupTerms)
                    8.5.4.1.8.3 [All Model Groups](#allGroupTerms)
            8.5.4.2 [EXI Normalized Grammars](#normalizedGrammars)
                8.5.4.2.1 [Eliminating Productions with no Terminal Symbol](#eliminatingProductions)
                8.5.4.2.2 [Eliminating Duplicate Terminal Symbols](#eliminatingSymbols)
            8.5.4.3 [Event Code Assignment](#eventCodeAssignment)
            8.5.4.4 [Undeclared Productions](#undeclaredProductions)
                8.5.4.4.1 [Adding Productions when Strict is False](#addingProductions)
                8.5.4.4.2 [Adding Productions when Strict is True](#addingProductionsStrict)
9. [EXI Compression](#compression)
    9.1 [Blocks](#blocks)
    9.2 [Channels](#channels)
        9.2.1 [Structure Channel](#StructureChannel)
        9.2.2 [Value Channels](#ValueChannels)
    9.3 [Compressed Streams](#CompressedStreams)
10. [Conformance](#conformance)
    10.1 [EXI Stream Conformance](#streamConformance)
    10.2 [EXI Processor Conformance](#processorConformance)

### Appendices

A [References](#References)
    A.1 [Normative References](#Normative-References)
    A.2 [Other References](#Informative-References)
B [Infoset Mapping](#InfosetMapping)
    B.1 [Document Information Item](#DocumentInformationItem)
    B.2 [Element Information Items](#ElementInformationItem)
    B.3 [Attribute Information Item](#AttributeInformationItem)
    B.4 [Processing Instruction Information Item](#ProcessingInstructionInformationItem)
    B.5 [Unexpanded Entity Reference Information item](#UnexpandedEntityInformationItem)
    B.6 [Character Information item](#CharacterInformationItem)
    B.7 [Comment Information item](#CommentInformationItem)
    B.8 [Document Type Declaration Information item](#DocumentTypeDeclaractionInformationItem)
    B.9 [Unparsed Entity Information Item](#UnparsedEntityInformationItem)
    B.10 [Notation Information Item](#NotationMapping)
    B.11 [Namespace Information Item](#NamespaceInformationItem)
C [XML Schema for EXI Options Document](#optionsSchema)
D [Initial Entries in String Table Partitions](#initialStringValues)
    D.1 [Initial Entries in Uri Partition](#initialUriValues)
    D.2 [Initial Entries in Prefix Partitions](#initialPrefixValues)
    D.3 [Initial Entries in Local-Name Partitions](#initialLocalNames)
E [Deriving
Set of Characters
from XML Schema Regular Expressions](#regexToCharset)
F [Content Coding and Internet Media Type](#mediaTypeRegistration)
    F.1 [Content Coding](#contentCoding)
    F.2 [Internet Media Type](#internetMediaType)
G [Example Encoding](#example) (Non-Normative)
H [Schema-informed Grammar Examples](#grammarExamples) (Non-Normative)
    H.1 [Proto-Grammar Examples](#exampleProtoGrammars)
    H.2 [Normalized Grammar Examples](#exampleNormGrammars)
    H.3 [Complete Grammar Examples](#exampleCompleteGrammars)
I [Recent Specification Changes](#changes) (Non-Normative)
    I.1 [Changes from First Edition Recommendation](#changes9)
    I.2 [Changes from previous versions of the document](#changes10)
J [Acknowledgements](#acknowledgements) (Non-Normative)

---

## 1. Introduction

The Efficient XML Interchange (EXI) format is a very compact, high
performance XML representation that was designed to work well for a
broad range of applications. It simultaneously improves performance
and significantly reduces bandwidth requirements without compromising
efficient use of other resources such as battery life, code size,
processing power, and memory.

EXI uses a grammar-driven approach that achieves very efficient
encodings using a straightforward encoding algorithm and a small set
of
datatype representations.
Consequently, [EXI processors](#key-exiprocessor) are relatively simple and
can be implemented on devices with limited capacity.

EXI is schema
"informed", meaning that it can utilize available schema
information to improve compactness and performance, but does not
depend on accurate, complete or current schemas to work. It supports
arbitrary schema extensions and deviations and also works very
effectively with partial schemas or in the absence of any schema. The
format itself also does not depend on any particular schema language,
or format, for schema information.

[Definition:]A program module
called an **EXI processor**, whether it is software or
hardware, is used by application programs to encode their structured data
into [EXI streams](#key-existream) and/or to decode
[EXI streams](#key-existream) to make the structured
data accessible.
The former and latter aforementioned roles of EXI processors are called [Definition:]**EXI stream encoder** and [Definition:]**EXI stream decoder**, respectively.
This document not only specifies the
EXI format, but also defines errors that EXI processors are required to
detect and behave upon.

The primary goal of this document is to define the EXI format completely without leaving ambiguity so as to make it feasible for implementations to interoperate. As such, the document lends itself to describing the design and features of the format in a systematic manner, often declaratively with relatively few prosaic annotations and examples. Those readers who prefer a step-by-step introduction to the EXI format design and features are suggested to start with the non-normative [[EXI Primer]](#exiprimer).

### 1.1 History and Design

EXI is the result of extensive work carried out by the W3C's XML
Binary Characterization (XBC) and Efficient XML Interchange (EXI)
Working Groups. XBC was chartered to investigate the costs and
benefits of an alternative form of XML, and formulate a way to objectively
evaluate the potential of a substitute format for XML. Based on XBC's
recommendations, EXI was chartered, first to measure, evaluate, and
compare the performance of various XML technologies (using metrics
developed by XBC [[XBC Measurement Methodologies]](#xbcmeas)), and then, if it appeared
suitable, to formulate a recommendation for a W3C format
specification. The measurements results and analyses, are presented
elsewhere [[EXI Measurements Note]](#eximeas). The format described in this
document is the specification so recommended.

The functional requirements of the EXI format are those that were
prepared by the XBC WG in their analysis of the desirable properties
of a high performance representation for XML [[XBC Properties]](#xbcproperties).
Those properties were derived from a very broad set of use cases also
identified by the XBC working group [[XBC Use Cases]](#xbcusecases).

The design of the format presented here, is largely based on the
results of the measurements carried out by the group to evaluate the
performance characteristics (mainly of processing efficiency and
compactness) of various existing formats. The EXI format is based on
Efficient XML [[Efficient XML]](#efx), including for example the basis heuristic grammar approach,
compression algorithm, and resulting entropy encoding.

EXI is compatible with XML at the XML Information Set [[XML Information Set]](#XMLInfoset) level, rather than at the XML syntax level. This
permits it to encapsulate an efficient alternative syntax and grammar
for XML, while facilitating at least the potential for minimizing the
impact on XML application interoperability.

### 1.2 Notational Conventions and Terminology

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD,
SHOULD NOT, RECOMMENDED, MAY, and OPTIONAL, when they appear
EMPHASIZED in this document, are to be interpreted as described in RFC
2119 [[IETF RFC 2119]](#RFC2119). Other terminology used to describe the EXI
format is defined in the body of this specification.

The term **event** and **stream** is used throughout this document to denote **[EXI event](#key-exievent)** and **[EXI stream](#key-existream)** respectively unless the words are qualified differently to mean otherwise.

This document specifies an abstract grammar for EXI. In grammar notation, all terminal
symbols are represented in plain text and all non-terminal symbols are
represented in *italics*. Grammar productions are
represented as follows:

|  |  |
| --- | --- |
|  | *LeftHandSide* :   Terminal  *NonTerminal* |

A set of one or more grammar productions that share the same
left-hand side non-terminal symbol are often presented together annotated
with [event codes](#key-eventcode) that specify how events matching the terminal symbols of the associated productions are represented in the EXI stream as follows:

|  |  |  |  |
| --- | --- | --- | --- |
|  | *LeftHandSide* : | | |
|  |  | Terminal1  *NonTerminal*1 | EventCode1 |
|  |  | Terminal2  *NonTerminal*2 | EventCode2 |
|  |  | Terminal3  *NonTerminal*3 | EventCode3 |
|  |  | ... |  |
|  |  | Terminaln  *NonTerminal*n | EventCoden |

Section [**8.1 Grammar Notation**](#grammarNotation) introduces additional notations for describing productions and [event codes](#key-eventcode) in grammars. Those additional notations facilitate concise representation of the EXI grammar system.

[Definition:]
In this document, the term **qname** is used to denote a
[QName](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#QName)XS2.
QName values are composed of an uri, a local-name and an optional prefix. Two qnames are considered equal if they have the same uri and local-name, regardless of their prefix values. In cases where prefixes are not relevant, such as in the grammar notation, they are not specified by this document.

Terminal symbols that are qualified with a qname permit the use of a wildcard symbol (\*) in place of or as part of a qname. The forms of terminal symbols involving qname wildcards used in grammars and their definitions are described in the table below.

| Wildcard | Definition |
| --- | --- |
| SE (\*) | The terminal symbol that matches a start element (SE) event with any qname. |
| SE (*uri* : \*) | The terminal symbol that matches a start element (SE) event with any local-name in namespace *uri*. |
| AT (\*) | The terminal symbol that matches an attribute (AT) event with any qname. |
| AT (*uri* : \*) | The terminal symbol that matches an attribute (AT) event with any local-name in namespace *uri*. |

Several prefixes are used throughout this document to designate certain namespaces. The bindings shown below are assumed, however, any prefixes can be used in practice if they are properly bound to the namespaces.

| Prefix | Namespace Name |
| --- | --- |
| exi | http://www.w3.org/2009/exi |
| xsd | http://www.w3.org/2001/XMLSchema |
| xsi | http://www.w3.org/2001/XMLSchema-instance |

In describing the layout of an EXI format construct, a pair of square brackets [ ] are used to surround the name of a field to denote that the occurrence of the field is optional in the structure of the part or component that contains the field.

In arithmetic expressions, the notation ⌈*x*⌉ where *x* represents a real number denotes the ceiling of *x*, that is, the smallest integer greater than or equal to *x*.

When it is stated that strings are sorted in lexicographical order,
it is done so character by character, and the order among characters is determined by comparing their Unicode code points.

Unless stated otherwise, when this specification indicates one type is derived from another type, it means the type is derived by extension or restriction, not by union or list. Similarly, when this specification uses the term type hierarchy, it is referring to the hierarchy of types derived from one another by extension or restriction

## 2. Design Principles

The following design principles were used to guide the development of EXI and encourage consistent design decisions. They are listed here to provide insight into the EXI design rationale and to anchor discussions on desirable EXI traits.

General:
:   One of primary objectives of EXI is to maximize the number of systems, devices and applications that can communicate using XML data. Specialized approaches optimized for specific use cases should be avoided.

Minimal:
:   To reach the broadest set of small, mobile and embedded applications, simple, elegant approaches are preferred to large, analytical or complex ones.

Efficient:
:   EXI must be competitive with hand-optimized binary formats so it can be used by applications that require this level of efficiency.

Flexible:
:   EXI must deal flexibly and efficiently with documents that contain arbitrary schema extensions or deviate from their schema. Documents that contain schema deviations should not cause encoding to fail.

Interoperable:
:   EXI must integrate well with existing XML technologies, minimizing the changes required to those technologies. It must be compatible with the XML Information Set [[XML Information Set]](#XMLInfoset), without significant subsetting or supersetting, in order to maintain interoperability with existing and prospective XML specifications.

## 3. Basic Concepts

EXI achieves broad generality, flexibility, and performance, by unifying concepts from formal language theory and information theory into a single, relatively simple algorithm. The algorithm uses a grammar to determine what is likely to occur at any given point in an XML document and encodes the most likely alternatives in fewer bits. The fully generalized algorithm works for any language that can be described by a grammar (e.g., XML, Java, HTTP, etc.); however, EXI is optimized specifically for XML languages.

The built-in EXI grammars accept any XML document or fragment and may be augmented with productions derived from schemas or other sources of information about what is likely to occur in a set of XML documents.
When schemas are used, EXI also supports a user-customizable set of Datatype Representations for efficiently representing typed values.
Though use of any schema languages including XML Schemas [[XML Schema Structures]](#schema1)
  [[XML Schema Datatypes]](#schema2), RELAX NG schemas [[ISO/IEC 19757-2:2008]](#relaxng), DTDs
[[XML 1.0]](#XML10)   [[XML 1.1]](#XML11) is permitted, EXI grammars and
datatype representations need to be given bindings for each schema language used.
This specification only defines how EXI grammars and datatype representations
relate to XML schema.

The [EXI stream encoder](#key-exiencoder) uses the grammar to map a stream of XML information items onto a smaller, lower entropy, stream of [events](#key-exievent).

The [EXI stream encoder](#key-exiencoder) then represents the stream of events using a set of simple variable length codes called [event codes](#key-eventcode). [Event codes](#key-eventcode) are similar to Huffman codes [[Huffman Coding]](#huffman), but are much simpler to compute and maintain. They are encoded directly as a sequence of values, or if additional compression is desired, they are passed to the [EXI compression](#compression) algorithm, which replaces frequently occurring event patterns to further reduce size.

## 4. EXI Streams

[Definition:]An **EXI stream** is an
[EXI header](#key-exiheader)
followed by an EXI body. [Definition:]The **EXI body** carries the content of the document, while the EXI header communicates the options used for encoding the EXI body. Section
[**5. EXI Header**](#header) describes the [EXI header](#key-exiheader).

[Definition:]The building block of an EXI body is an **EXI event**. An EXI body consists of a sequence of EXI events representing an [EXI document](#key-exidocument) or an [EXI fragment](#key-exifragment).

The EXI events permitted at any given position in an EXI stream are determined by the EXI grammar.
As is the case with XML,
the events occur with nesting pairs of matching start element and end element events where any pair does not intersect with another except when it is fully contained in the other.
The EXI grammar incorporates knowledge of the XML grammar and may be augmented and refined using schema information and fidelity options. The EXI grammar is formally specified in section [**8. EXI Grammars**](#grammars).

An EXI body can represent an EXI document with a single root element or an EXI fragment with zero or more root elements.
[Definition:]
**EXI documents** are EXI bodies with a single root element that conform to the Built-in Document Grammar (See [**8.4.1 Built-in Document Grammar**](#builtinDocGrammars)) or Schema-informed Document Grammar (See [**8.5.1 Schema-informed Document Grammar**](#informedDocGrammars)).
[Definition:]
**EXI fragments** are EXI bodies with zero or more root elements that conform to the Built-in Fragment Grammar (See [**8.4.2 Built-in Fragment Grammar**](#builtinFragGrammars)) or Schema-informed Fragment Grammar (See [**8.5.2 Schema-informed Fragment Grammar**](#informedFragGrammars)).

[Definition:]When schema information is available to describe the contents of an EXI body, such an EXI stream is a **schema-informed EXI stream** and the EXI body is interpreted according to the Schema-informed Document Grammar (See [**8.5.1 Schema-informed Document Grammar**](#informedDocGrammars)) or Schema-informed Fragment Grammar (See [**8.5.2 Schema-informed Fragment Grammar**](#informedFragGrammars)).
[Definition:]Otherwise, an EXI stream is a **schema-less EXI stream**, and the EXI body is interpreted according to the Built-in Document Grammar (See [**8.4.1 Built-in Document Grammar**](#builtinDocGrammars)) or Built-in Fragment Grammar (See [**8.4.2 Built-in Fragment Grammar**](#builtinFragGrammars)).

The following table summarizes the EXI event types and associated event content that occur in an EXI stream.
[Definition:]
The content of an event consists of **content items**,
and the content items appear in an EXI stream in the order they are shown in the table
following their respective [event codes](#key-eventcode) that
each marks the start of an [event](#key-exievent).
In addition, the table includes the grammar notation used to represent each [event](#key-exievent) in this specification. Each [event](#key-exievent) in an EXI stream participates in a mapping system that relates [events](#key-exievent) to XML Information Items so that an EXI document
or an EXI fragment
as a whole serves to represent an XML Information Set. The table shows XML Information Items relevant to each EXI event. Appendix [**B Infoset Mapping**](#InfosetMapping) describes the mapping system in detail.

Table 4-1. EXI events

| EXI Event Type | Event Content (Content Items) | Grammar Notation (Terminal Symbols) | Information Item |
| --- | --- | --- | --- |
| Start Document |  | SD | [**B.1 Document Information Item**](#DocumentInformationItem) |
| End Document |  | ED |
| Start Element | *qname* | SE ( *qname* ) | [**B.2 Element Information Items**](#ElementInformationItem) |
| SE ( \* ) |
| SE ( *uri :*\* ) |
| End Element |  | EE |
| Attribute | *qname, value* | AT ( *qname* ) | [**B.3 Attribute Information Item**](#AttributeInformationItem) |
| AT ( \* ) |
| AT ( *uri :*\* ) |
| Characters | *value* | CH | [**B.6 Character Information item**](#CharacterInformationItem) |
| Namespace Declaration | *uri*, *prefix*, *local-element-ns* | NS | [**B.11 Namespace Information Item**](#NamespaceInformationItem) |
| Comment | *text* | CM | [**B.7 Comment Information item**](#CommentInformationItem) |
| Processing Instruction | *name, text* | PI | [**B.4 Processing Instruction Information Item**](#ProcessingInstructionInformationItem) |
| DOCTYPE | *name, public, system, text* | DT | [**B.8 Document Type Declaration Information item**](#DocumentTypeDeclaractionInformationItem) |
| Entity Reference | *name* | ER | [**B.5 Unexpanded Entity Reference Information item**](#UnexpandedEntityInformationItem) |
| Self Contained |  | SC |  |

Section
[**6. Encoding EXI Streams**](#encodingEvents) describes the algorithm used to encode [events](#key-exievent) in the EXI stream.
As indicated in the table above, there are some event types that carry content with their [event](#key-exievent) instances while other event types function as markers without content.

SE events may be followed by a series of NS events. Each NS event either associates a prefix with an URI, assigns a default namespace, or in the case of a namespace declaration with an empty URI, rescinds one of such associations in effect at the point of its occurrence. The effect of the association or disassociation caused by a NS event stays in effect until the corresponding EE event occurs.

Like XML, the namespace of a particular element may be specified by a namespace declaration
preceding
the element or a local namespace declaration following the element name. When the namespace is specified by a local namespace declaration, the *local-element-ns* flag of the associated NS event is set to true and the prefix of the element is set to the prefix of that NS event. When the namespace is specified by a previous namespace declaration, the *local-element-ns* flag of all local NS events is false and the prefix of the element is set according to the prefix component of the element *qname*. The series of NS events associated with a particular element may include at most one NS event with its
*local-element-ns* flag
set to true. The *uri* of a NS event with its
*local-element-ns* flag
set to true MUST match the *uri* of the associated SE event.

The namespace of elements and attributes is specified as part of SE and AT events and hence namespace declarations can be omitted from the EXI stream if preservation of prefixes is not required by the applications. As prescribed by [Table B-2](#MappingElement) and [Table B-11](#MappingNamespace), [namespace attributes] representing namespace declarations are mapped to NS events and SHOULD NOT be represented by AT events. This also implies that the following AT events SHOULD NOT occur in EXI streams: (1) AT events with qname whose uri is "http://www.w3.org/2000/xmlns/"; (2) AT events with qname which has empty uri ("") and local name either of the form "xmlns" or "xmlns:\*", where "\*" represents a string with 0 or more characters.

An SE event may be followed by a SC event, indicating the element is self-contained and can be read independently from the rest of the EXI body. Applications may use self-contained elements to index portions of the EXI body for random access.

The representation of [event codes](#key-eventcode) which identify the event type and start each event is described in [**6.2 Representing Event Codes**](#encodingEventCodes).
Each item in the event content has a
datatype representation
associated with it as shown in the following table. The content of each [event](#key-exievent), if any, is encoded as a sequence of items each of which being encoded according to its
datatype representation
in order starting with the first item followed by subsequent items.

Table 4-2. Datatype representations of event content items

| Content item | Used in | Datatype representation |
| --- | --- | --- |
| *name* | PI, DT, ER | [**7.1.10 String**](#encodingString) |
| *prefix* | NS | [**7.1.10 String**](#encodingString) |
| *local-element-ns* | NS | [**7.1.2 Boolean**](#encodingBoolean) |
| *public* | DT | [**7.1.10 String**](#encodingString) |
| *qname* | SE, AT | [**7.1.7 QName**](#encodingQName) |
| *system* | DT | [**7.1.10 String**](#encodingString) |
| *text* | CM, PI, DT | [**7.1.10 String**](#encodingString) |
| *uri* | NS | [**7.1.10 String**](#encodingString) |
| *value* | CH, AT | According to the schema datatype (see [**7. Representing Event Content**](#encodingValues)) if any is in effect, otherwise [**7.1.10 String**](#encodingString) |

The datatype representation
used for each [*value*](#key-valueContentItem) content item depends on the schema
[datatype](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#datatype)XS2
if any that is in effect for that [*value*](#key-valueContentItem).
The String datatype representation (see [**7.1.10 String**](#encodingString))
is used for [*values*](#key-valueContentItem) that do not have an associated schema datatype,
cannot be or are opted not to be represented by their associated datatype representations,
or occur in mixed content. Section
[**7. Representing Event Content**](#encodingValues) describes how each of the types listed above are encoded in an EXI stream.

**Note:**

The syntax and semantics of the NS event are designed to minimize the overhead required for representing namespace prefixes in EXI streams without introducing significant complexity. In the common case where each namespace is bound to a single prefix, this design reduces the overhead for representing all element and attribute namespace prefixes to zero bits.

## 5. EXI Header

Each [EXI stream](#key-existream) begins with an EXI header.
[Definition:]
The **EXI header**
can identify EXI streams,
distinguish EXI
streams
from text XML documents,
identify the version of the EXI format being used, and specify the options used to process the body of the EXI stream.
The EXI header has the following structure:

|  |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- |
| [[ EXI Cookie ]](#key-exiCookie) | [Distinguishing Bits](#key-distinguishingbits) | Presence Bit | [EXI Format](#key-version) | [[EXI Options](#key-options)] | [Padding Bits] |
| for EXI Options | [Version](#key-version) |

The EXI Options field within an EXI header is optional. Its presence is indicated by
the value of the presence bit that follows [Distinguishing Bits](#key-distinguishingbits). The presence and absence is indicated by the value 1 and 0, respectively.

When the [compression](#key-compressionOption) option is true, or the [alignment](#key-alignmentOption) option is [byte-alignment](#key-bytealignment) or [pre-compression](#key-precompression),
padding bits of minimum length required to make the whole length of
the header byte-aligned are added at the end of the header.
On the other hand, there are no padding bits when the alignment in use is [bit-packed](#key-unaligned).
The padding bits field
if it is present
can contain any values of bits as its contents.

The details of the
[EXI Cookie](#key-exiCookie),
[Distinguishing Bits](#key-distinguishingbits), [EXI Format Version](#key-version) and [EXI Options](#key-options) are described in the following sections.

### 5.1 EXI Cookie

[Definition:]
An [EXI header](#key-exiheader) MAY start with an **EXI Cookie**,
which is a four byte field that serves to indicate that the stream of which it is a part is an EXI stream. The four byte field consists of four characters
" $ " , " E ", " X " and " I "
in that order, each represented as an ASCII octet, as follows.

|  |  |  |  |
| --- | --- | --- | --- |
| '$' | 'E' | 'X' | 'I' |

This four byte sequence is particular to EXI and specific enough to distinguish EXI streams from a broad range of data types currently used on the Web. While the EXI cookie is optional, its use is RECOMMENDED in the EXI header when the EXI stream is exchanged in a context where a longer, more specific content-based datatype identifier is desired than that provided by the [Distinguishing Bits](#key-distinguishingbits), whose role is more narrowly focused on distinguishing EXI streams from XML documents.

### 5.2 Distinguishing Bits

[Definition:]
The second part in the EXI header is the **Distinguishing Bits**,
which is a two bit field of which the first bit contains the value 1 and the second bit contains the value 0, as follows.

|  |  |
| --- | --- |
| 1 | 0 |

Unlike the optional EXI cookie that MAY occur to precede this field, the presence of Distinguishing Bits is REQUIRED in the EXI header. It is used to distinguish EXI streams from text XML documents in the absence of an [EXI cookie](#key-exiCookie).
This two bit sequence is the minimum that suffices to distinguish EXI
streams from XML documents since it is the minimum length bit
pattern that cannot occur as the first two bits of a well-formed XML
document represented in any one of the conventional character
encodings, such as UTF-8, UTF-16, UTF-32, UCS-2, UCS-4, EBCDIC, ISO 8859,
Shift-JIS and EUC, according to
XML [[XML 1.0]](#XML10)   [[XML 1.1]](#XML11).
Therefore, XML Processors that do not support EXI are expected to reject an EXI stream as early as they read
and process the first byte from the stream.

Systems that use EXI streams as well as XML documents can reliably look at
the Distinguishing Bits to determine whether to interpret a particular
stream as XML or EXI.

### 5.3 EXI Format Version

[Definition:]
The fourth part in the EXI header is the **EXI Format Version**, which identifies the version of the EXI format being used.
EXI format version numbers are integers. Each version of the EXI Format Specification specifies the corresponding EXI format version number to be used by conforming implementations. The EXI format version number that corresponds with this version of the EXI format specification is 1 (one).

The first bit of the version field indicates whether the version is a preview or final version of the EXI format.
A value of 0 indicates this is a final version and a value of 1 indicates this is a preview
version. Final versions correspond to final, approved versions of the EXI format specification.
An [EXI processor](#key-exiprocessor) that implements a final version of the EXI format specification is REQUIRED to process EXI streams that have a version field with its first bit set to 0 followed by a version number that corresponds to the version of the EXI specification the processor implements. The behavior of an EXI processor on an EXI stream with its first bit set to 0 followed by a version not corresponding to a version implemented by the processor is not constrained by this specification. For example, the EXI processor MAY reject such a stream outright or it MAY attempt to process the EXI body.
Preview versions of the EXI format are useful for
gaining implementation and deployment experience prior to finalizing a
particular version of the EXI format. While preview versions may match drafts of this specification, they are not governed by this specification and the behaviour of EXI processors encountering preview versions of the EXI format is implementation dependent. Implementers are free to coordinate to achieve interoperability between different preview versions of the EXI format.

Following the first bit of the version is a sequence of one or more
4-bit unsigned integers representing the version number. The version
number is determined by summing this sequence of 4-bit unsigned
values and adding 1 (one). The sequence is terminated by any 4-bit unsigned integer with
a value in the range 0-14. As such, the first 15 version numbers are
represented by 4 bits, the next 15 are represented by 8 bits, etc.

Given an EXI stream with its stream cursor positioned just past the first bit of the EXI format version field, the EXI format version number can be computed by going through the following steps with version number initially set to 1.

1. Read next 4 bits as an unsigned integer value.
2. Add the value that was just read to the version number.
3. If the value is 15, go to step 1, otherwise (i.e. the value being in the range of 0-14), use the current value of the version number as the EXI version number.

The following are example EXI format version numbers.

*Example 5-1. EXI Format Version Examples*

| EXI Format Version Field | Description |
| --- | --- |
| 1 0000 | Preview version 1 |
| 0 0000 | Final version 1 |
| 0 1110 | Final version 15 |
| 0 1111 0000 | Final version 16 |
| 0 1111 0001 | Final version 17 |

[EXI processors](#key-exiprocessor) conforming with the final version of this
specification MUST use the 5-bit value 0 0000 as the version
number.

### 5.4 EXI Options

[Definition:]The
fifth
part of the EXI
header is the **EXI Options**, which provides a way to specify the
options used to encode the body of the EXI stream.
[Definition:]
The EXI Options are represented as an **EXI Options document**, which is an XML document encoded using the EXI format described in this specification.
This results in a very compact header
format that can be read and written with very little additional software.

The presence of EXI Options in its entirety is optional in EXI header,
and it is predicated on the value of the presence bit that follows the
[Distinguishing Bits](#key-distinguishingbits).
When EXI Options are present in the header, an EXI Processor MUST observe the
specified options to process the EXI stream that follows. Otherwise,
an EXI Processor may obtain the EXI options using another mechanism.
There are no fallback option values provided by this specification for use
in the absence of the whole EXI Options part.

[EXI processors](#key-exiprocessor) MAY provide external means for applications or users to
specify EXI Options when the EXI Options document is absent.
Such [EXI processors](#key-exiprocessor) are typically used in controlled systems
where the knowledge about the effective EXI Options is shared prior to
the exchange of EXI
streams. The mechanisms to communicate out-of-band EXI Options and their representation are implementation dependent.

The following table describes the EXI options that may be specified in the
EXI Options document.

Table 5-1. EXI Options in Options Document

| EXI Option | Description | Default Value |
| --- | --- | --- |
| [alignment](#key-alignmentOption) | Alignment of [event codes](#key-eventcode) and [content items](#key-content-item) | [bit-packed](#key-unaligned) |
| [compression](#key-compressionOption) | EXI compression is used to achieve better compactness | false |
| [strict](#key-strictOption) | Strict interpretation of schemas is used to achieve better compactness | false |
| [fragment](#key-fragmentOption) | Body is encoded as an [EXI fragment](#key-exifragment) instead of an [EXI document](#key-exidocument) | false |
| [preserve](#key-preserveOption) | Specifies whether the support for the preservation of comments, pis, etc. is each enabled | all false |
| [selfContained](#key-selfContained) | Enables self-contained elements | false |
| [schemaId](#key-schemaIdOption) | Identify the schema information, if any, used to encode the body | *no default value* |
| [datatypeRepresentationMap](#key-datatypeRepresentationOption) | Specify alternate datatype representations for typed [*values*](#key-valueContentItem) in the [EXI body](#key-exibody) | *no default value* |
| [blockSize](#key-blockSizeOption) | Specifies the block size used for EXI compression | 1,000,000 |
| [valueMaxLength](#key-valueMaxLengthOption) | Specifies the maximum string length of [*value*](#key-valueContentItem) content items to be considered for addition to the string table. | unbounded |
| [valuePartitionCapacity](#key-valuePartitionCapacityOption) | Specifies the total capacity of value partitions in a string table | unbounded |
| [[user defined meta-data]](#key-userMetaData) | User defined meta-data may be added | *no default value* |

Appendix [**C XML Schema for EXI Options Document**](#optionsSchema) provides an XML Schema
describing
[the EXI Options document](#key-optionsDoc).
This schema is designed to produce smaller headers
for option combinations used when compactness is critical.

The [EXI Options document](#key-optionsDoc) is
represented as an [EXI body](#key-exibody)
informed by the above mentioned schema using the default options
specified by the following XML document.
An EXI Options document consists only of an EXI body, and MUST NOT
start with an EXI header.

Header options used for encoding the [EXI Options document](#key-optionsDoc)

```

  <header xmlns="http://www.w3.org/2009/exi">
    <strict/>
  </header>
```

Note that this specification does not require [EXI processors](#key-exiprocessor) to read and process the schema prescribed for EXI options document ([**C XML Schema for EXI Options Document**](#optionsSchema)), in order to process EXI options documents. EXI processors MUST use the schema-informed grammars that stem from the schema in processing EXI options documents, beyond which there is no requirement as to the use of the schema, and implementations are free to use any methods to retrieve the instructions that observe the grammars for processing EXI options documents. Section [**8.5 Schema-informed Grammars**](#informedGrammars) describes the system to derive schema-informed grammars from XML Schemas.

Below is a brief description of each EXI option.

[Definition:]The **alignment option** is used to control the alignment of [event codes](#key-eventcode) and [content items](#key-content-item). The value is one of [bit-packed](#key-unaligned), [byte-alignment](#key-bytealignment) or [pre-compression](#key-precompression), of which [bit-packed](#key-unaligned) is the default value assumed when the "alignment" element is absent in the [EXI Options document](#key-optionsDoc).
The option values [byte-alignment](#key-bytealignment) and [pre-compression](#key-precompression) are effected when "byte" and "pre-compress" elements are present in the EXI Options document, respectively.
When the value of [compression option](#key-compressionOption) is set to true, alignment of the EXI Body is governed by the rules specified in [**9. EXI Compression**](#compression) instead of the alignment option value. The "alignment" element MUST NOT appear in an EXI options document when the "compression" element is present.

[Definition:]The alignment option value **bit-packed** indicates that the [event codes](#key-eventcode) and associated content are packed in bits without any padding in-between.

[Definition:]The alignment option value **byte-alignment** indicates that the [event codes](#key-eventcode) and associated content are aligned on byte boundaries. While byte-alignment generally results in EXI streams of larger sizes compared with their bit-packed equivalents, byte-alignment may provide a help in some use cases that involve frequent copying of large arrays of scalar data directly out of the stream. It can also make it possible to work with data in-place and can make it easier to debug encoded data by allowing items on aligned boundaries to be easily located in the stream.

[Definition:]The alignment option value **pre-compression** indicates that all steps involved in compression (see section [**9. EXI Compression**](#compression)) are to be done with the exception of the final step of applying the DEFLATE algorithm. The primary use case of pre-compression is to avoid a duplicate compression step when compression capability is built into the transport protocol. In this case, pre-compression just prepares the stream for later compression.

[Definition:]The **compression option** is a Boolean used to increase compactness using additional computational resources. The default value "false" is assumed when the "compression" element is absent in the [EXI Options document](#key-optionsDoc) whereas its presence denotes the value "true".
When set to true, the [event codes](#key-eventcode) and associated content are compressed according to [**9. EXI Compression**](#compression) regardless of the [alignment](#key-alignmentOption) option value. As mentioned above, the "compression" element MUST NOT appear in an EXI options document when the "alignment" element is present.

[Definition:]The **strict option** is a Boolean used to increase compactness by using a strict interpretation of the schemas and omitting preservation of certain items, such as comments, processing instructions and namespace prefixes. The default value "false" is assumed when the "strict" element is absent in the [EXI Options document](#key-optionsDoc)
whereas its presence denotes the value "true".
When set to true,
those productions that have NS, CM, PI, ER, and SC terminal symbols are omitted from the
EXI grammars, and schema-informed element and type grammars are restricted to only permit items declared in the schemas.
A note in section [**8.5.4.4.2 Adding Productions when Strict is True**](#addingProductionsStrict) describes some additional restrictions consequential of the use of this option.
The "strict" element MUST NOT appear in an [EXI options document](#key-optionsDoc) when
one of "dtd", "prefixes", "comments", "pis" or "selfContained"
element is present in the same options document.

[Definition:]The **fragment option** is a Boolean that indicates whether the [EXI body](#key-exibody) is an [EXI document](#key-exidocument) or an [EXI fragment](#key-exifragment). When set to true, the [EXI body](#key-exibody) is an [EXI fragment](#key-exifragment). Otherwise, the [EXI body](#key-exibody) is an [EXI document](#key-exidocument). The default value "false" is assumed when the "fragment" element is absent in the [EXI Options document](#key-optionsDoc)
whereas its presence denotes the value "true".

[Definition:]The **preserve option** is a set of Booleans that can be set independently
to each enable or disable a share of the format's capacity determining whether or how certain information items can be preserved in the EXI stream.
Section [**6.3 Fidelity Options**](#fidelityOptions) describes the set of information items
affected by the preserve option.
The presence of "dtd", "prefixes", "lexicalValues", "comments" and "pis" in the EXI Options document each turns on fidelity options Preserve.comments, Preserve.pis, Preserve.dtd, Preserve.prefixes and Preserve.lexicalValues whereas the absence denotes turning each off.
The elements "dtd", "prefixes", "comments" and "pis"
MUST NOT appear in an [EXI options document](#key-optionsDoc) when the "strict" element is present in the same options document.
The element "lexicalValues", on the other hand, is permitted to occur in the presence of "strict" element.

[Definition:]The **selfContained option** is a Boolean used to enable the use of self-contained elements in the EXI stream. Self-contained elements may be read independently from the rest of the EXI body, allowing them to be indexed for random access. The "selfContained" element MUST NOT appear in an [EXI options document](#key-optionsDoc) when
one of "compression", "pre-compression" or "strict" elements are present
in the same options document. The default value "false" is assumed when the "selfContained" element is absent from the [EXI Options document](#key-optionsDoc)
whereas its presence denotes the value "true".

[Definition:]The **schemaId option** may be used to identify the schema information used
for processing
the EXI body. When the
"schemaId" element in the [EXI options document](#key-optionsDoc) contains the xsi:nil attribute
with its value set to true,
no schema information
is used for processing
the EXI body (i.e. a [schema-less EXI stream](#key-schemaless-existream)).
When the value of the "schemaId" element is empty, no user defined schema information is used for processing the EXI body;
however, the built-in XML schema types are available for use in the EXI body.
When the schemaId option is absent (i.e., undefined), no statement is made about the schema information used to encode the EXI body and this information
MUST be communicated out of band.
This specification does not dictate the syntax or semantics of other values specified in this field. An example schemaId scheme is the use of URI that is apt for globally identifying schema resources on the Web.
The parties involved in the exchange are free to agree on the scheme of schemaId field that is appropriate for their use to uniquely identify the schema information.

[Definition:]The **datatypeRepresentationMap option**
specifies an alternate set of datatype representations for typed
[*values*](#key-valueContentItem) in
the [EXI body](#key-exibody)
as described in [**7.4 Datatype Representation Map**](#datatypeRepresentationMap).
When there are no "datatypeRepresentationMap" elements in the [EXI Options document](#key-optionsDoc), no Datatype Representation Map is used for processing the EXI body.
This option does not take effect when the value of the Preserve.lexicalValues fidelity option is true (see [**6.3 Fidelity Options**](#fidelityOptions)),
or when the [EXI stream](#key-existream) is a [schema-less EXI stream.](#key-schemaless-existream)

[Definition:]The **blockSize option** specifies the block size used for EXI compression. When the "blockSize" element is absent in the [EXI Options document](#key-optionsDoc), the default blocksize of 1,000,000 is used. The default blockSize is intentionally large but can be reduced for processing large documents on devices with limited memory.

[Definition:]
The **valueMaxLength option** specifies the maximum length of [*value*](#key-valueContentItem) content items to be considered for addition to the string table.
The default value "unbounded" is assumed when the "valueMaxLength" element is absent in the [EXI Options document](#key-optionsDoc).

[Definition:]
The **valuePartitionCapacity option** specifies the maximum number of [*value*](#key-valueContentItem) content items in the string table at any given time.
The default value "unbounded" is assumed when the "valuePartitionCapacity" element is absent in the [EXI Options document](#key-optionsDoc).
Section [**7.3.3 Partitions Optimized for Frequent use of String Literals**](#encodingOptimizedForMisses) specifies the behavior of the string table when this capacity is reached.

[Definition:]
The **user defined meta-data** conveys auxiliary information that applications may use to facilitate interpretation of the EXI stream.
The user defined meta-data MUST NOT be interpreted in a way that alters or extends the EXI data format defined in this specification.
User defined meta-data may be added to an EXI Options document just prior to the [alignment](#key-alignmentOption) option.

## 6. Encoding EXI Streams

The rules for encoding a series of [events](#key-exievent) as an [EXI stream](#key-existream) are very
simple and are driven by a declarative set of grammars that describes
the structure of an [EXI stream](#key-existream). Every [event](#key-exievent) in the stream is
encoded using the same set of encoding rules, which are summarized as
follows:

1. Get the next event
   data
   to be encoded
2. If fidelity options (see [**6.3 Fidelity Options**](#fidelityOptions)) indicate this event type is not processed,
   go to step 1
3. Use the grammars to determine the [event code](#key-eventcode) of the [event](#key-exievent)
4. Encode the [event code](#key-eventcode) followed by the event content (see [Table 4-1](#eventTypes))
5. Evaluate the grammar production matched by the [event](#key-exievent)
6. Repeat until the End Document (ED) event is encoded

Self-contained (SC), namespace (NS) and attribute (AT) events associated with a given element occur directly after the start element (SE) event in the following order:

|  |  |  |  |  |  |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| SC | NS | NS | ... | NS | AT (xsi:type) | AT (xsi:nil) | AT | AT | ... | AT |

Namespace (NS) events occur in document order.
The xsi:type and xsi:nil attributes
occur before all other AT events.
When the grammar currently in effect for the element is either a [built-in element grammar](#key-builtin-elem-grammar) (see [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars)) or a [schema-informed element fragment grammar](#key-informed-elem-fragment-grammar) (see [**8.5.3 Schema-informed Element Fragment Grammar**](#informedElementFragGrammar)), the remaining attribute (AT) events can occur in any order. Otherwise, when the grammar in effect is a [schema-informed element grammar](#key-informedElementGrammar) or a [schema-informed type grammar](#key-informedTypeGrammar) (see [**8.5.4 Schema-informed Element and Type Grammars**](#informedElemGrammars)), the remaining attributes can occur in any order that is permitted by the grammar, though in practice they SHOULD occur in lexicographical order sorted first by *qname* local-name then by *qname* uri for achieving better compactness, where a *qname* is a [qname](#key-qname) of an attribute.

**Note:**

Under certain circumstances, it is not strictly required that the xsi:type or xsi:nil attributes occur before other AT events of the same element. See the notes in section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars) for details.

EXI uses the same simple procedure described above, to encode well-formed documents, document fragments, schema-valid information items, schema-invalid information items, information items partially described by schemas and information items with no schema at all. Only the grammars that describe these items differ. For example, an element with no schema information is encoded according to the XML grammar defined by the XML specification, while an element with schema information is encoded according to the more specific grammar defined by that schema.

[Definition:]An **event code** is a sequence of 1 to 3 non-negative integers called parts used to identify each event in an EXI stream. The EXI grammars describe which events may occur at each point in an EXI stream and associate an even code with each one.
(See [**8.2 Grammar Event Codes**](#grammarEventCodes) for more description of event codes.)

Section [**6.1 Determining Event Codes**](#eventCodes) describes in detail how the grammar is used to determine the event code of an [event](#key-exievent). Section [**6.2 Representing Event Codes**](#encodingEventCodes) describes in detail how event codes are represented as bits. Section
[**6.3 Fidelity Options**](#fidelityOptions) describes available fidelity options and how they
affect
the EXI stream. Section [**7. Representing Event Content**](#encodingValues) describes how the typed event contents are represented as bits.

### 6.1 Determining Event Codes

The structure of an EXI stream is described by the EXI grammars, which are formally specified in section
[**8. EXI Grammars**](#grammars). Each grammar defines which events are permitted to occur at any given point in the EXI stream and provides a pre-assigned [event code](#key-eventcode) for each one.

For example, the grammar productions below describe the events that can occur in a schema-informed EXI stream after the Start-Document (SD) event provided there are four global elements defined in the schema and assign an [event code](#key-eventcode) for each one.
See [**8.5.1 Schema-informed Document Grammar**](#informedDocGrammars) for the process used for generating the grammar productions below from the schema.

*Example 6-1. Example productions with event codes*

|  | | | |
| --- | --- | --- | --- |
| Syntax | | | Event Code |
|  | *DocContent* | | |
|  |  | SE ("A") *DocEnd* | 0 |
|  |  | SE ("B") *DocEnd* | 1 |
|  |  | SE ("C") *DocEnd* | 2 |
|  |  | SE ("D") *DocEnd* | 3 |
|  |  | SE (\*) *DocEnd* | 4 |
|  |  | DT *DocContent* | 5.0 |
|  |  | CM *DocContent* | 5.1.0 |
|  |  | PI *DocContent* | 5.1.1 |

At the point in an EXI stream where the above grammar productions are in effect, the [event code](#key-eventcode) of Start Element "A" (i.e. SE("A")) is 0. The event code of a DOCTYPE (DT) event at this point in the stream is 5.0, and so on.

### 6.2 Representing Event Codes

Each [event code](#key-eventcode) is represented by a sequence of 1 to 3 parts that uniquely identify an event.
[Event code](#key-eventcode) parts are encoded in order starting with the first part followed by subsequent parts.

The
*i*-th part of an [event code](#key-eventcode) is encoded as an *n*-bit unsigned integer ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)), where
*n* is ⌈ log2 *m* ⌉ and *m* is the number of distinct values used as the
*i*-th part of its own and all its sibling event codes in the current grammar.
Two [event codes](#key-eventcode) are siblings at the *i*-th part if and only if they share the same values in all preceding parts. All [event codes](#key-eventcode) are siblings at the first part.

If there is only one distinct value for a given part, the part is omitted (i.e., encoded in log2 1 = 0 bits = 0 bytes).

For example, the eight [event codes](#key-eventcode) shown in the
*DocContent* grammar above have values ranging from 0 to 5 for the first part. Six distinct values are needed to identify the first part of these [event codes](#key-eventcode).
Therefore, the first part can be encoded as an *n*-bit unsigned integer where *n* = ⌈ log2 6 ⌉ = 3. In the same fashion, the second and third part (if present) are represented as *n*-bit unsigned integers where *n* is ⌈ log2 2 ⌉ = 1  and ⌈ log2 2 ⌉ = 1  respectively.

When the value of the [compression option](#key-compressionOption) is false and [bit-packed](#key-unaligned) alignment is used, *n*-bit unsigned integers are represented using *n* bits. The first table below illustrates how the [event codes](#key-eventcode) of each
event matched by the *DocContent* grammar above are represented in this case.

When the value of [compression option](#key-compressionOption) is true, or either [byte-alignment](#key-bytealignment) or [pre-compression](#key-precompression) alignment option is used, *n*-bit unsigned integers are represented using the minimum number of bytes required to store *n* bits. The second table below illustrates how the [event codes](#key-eventcode) of each
event matched by the *DocContent* grammar above are represented in this case.

*Example 6-2. Example event code encoding*

Table 6-1. Example event code encoding
when EXI compression is not in effect and [bit-packed](#key-unaligned) alignment option is used

| Event | Part values | | | Event Code Encoding | # bits |
| --- | --- | --- | --- | --- | --- |
| SE ("A") | 0 |  |  | 000 | 3 |
| SE ("B") | 1 |  |  | 001 | 3 |
| SE ("C") | 2 |  |  | 010 | 3 |
| SE ("D") | 3 |  |  | 011 | 3 |
| SE (\*) | 4 |  |  | 100 | 3 |
| DT | 5 | 0 |  | 101  0 | 4 |
| CM | 5 | 1 | 0 | 101  1  0 | 5 |
| PI | 5 | 1 | 1 | 101  1  1 | 5 |

|  |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- |
| # distinct values (*m*) | 6 | 2 | 2 |  |  |
| |  | | --- | | # bits per part | | ⌈ log 2 *m* ⌉ | | 3 | 1 | 1 |  |  |

Table 6-2. Example event code encoding
when EXI compression is in effect, or either
[byte-alignment](#key-bytealignment) or [pre-compression](#key-precompression) alignment option is used

| Event | Part values | | | Event Code Encoding | # bytes |
| --- | --- | --- | --- | --- | --- |
| SE ("A") | 0 |  |  | 00000000 | 1 |
| SE ("B") | 1 |  |  | 00000001 | 1 |
| SE ("C") | 2 |  |  | 00000010 | 1 |
| SE ("D") | 3 |  |  | 00000011 | 1 |
| SE (\*) | 4 |  |  | 00000100 | 1 |
| DT | 5 | 0 |  | 00000101  00000000 | 2 |
| CM | 5 | 1 | 0 | 00000101  00000001  00000000 | 3 |
| PI | 5 | 1 | 1 | 00000101  00000001  00000001 | 3 |

|  |  |  |  |  |  |
| --- | --- | --- | --- | --- | --- |
| # distinct values (*m*) | 6 | 2 | 2 |  |  |
| |  | | --- | | # bytes per part | | ⌈ (log 2 *m*) / 8 ⌉ | | 1 | 1 | 1 |  |  |

### 6.3 Fidelity Options

Some XML applications do not require the entire XML feature set and would prefer to eliminate the overhead associated with unused features. For example, the SOAP 1.2 specification
[[SOAP 1.2]](#soap12) prohibits the use of XML
processing instructions.
In addition, there are many data-exchange use cases that do not require XML comments or DTDs.

The [preserve option](#key-preserveOption) in EXI Options comprises a set of fidelity options, each of which independently
enables or disables the format's capacity for
the preservation (or preservation level) of a certain type of information item.
Applications can use the [preserve option](#key-preserveOption) to specify the set of fidelity options they require.
As specified in section
[**8.3 Pruning Unneeded Productions**](#pruningProductions), EXI processors MUST use these fidelity options to prune
productions that match the associated events from the grammars, improving compactness and processing efficiency.

The table below lists the fidelity options supported by this version of the EXI specification and describes the effect setting these options has on the [EXI stream](#key-existream).

Table 6-3. Fidelity options

| Fidelity option | Effect |
| --- | --- |
| Preserve.comments | CM events can be preserved |
| Preserve.pis | PI events can be preserved |
| Preserve.dtd | DT and ER events can be preserved |
| Preserve.prefixes | NS events and namespace prefixes can be preserved |
| Preserve.lexicalValues | Lexical form of element and attribute values can be preserved in [*value*](#key-valueContentItem) content items |

When qualified names [[Namespaces in XML 1.0]](#XMLNS10)   [[Namespaces in XML 1.1]](#XMLNS11) are used in the [*value*s](#key-valueContentItem) of AT or CH events in an EXI Stream, the Preserve.prefixes fidelity option SHOULD be turned on to enable the preservation of the NS prefix declarations used by these values.
Note, in particular among other cases, that this practice applies to the use of xsi:type attributes in EXI streams when Preserve.lexicalValues fidelity option is set to *true*.

See section [**4. EXI Streams**](#streams) for the definition of EXI event types and their associated [content items](#key-content-item).

## 7. Representing Event Content

The [event code](#key-eventcode) of each event in an EXI body is represented as a sequence of
*n*-bit unsigned integers ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)).
See section [**6.2 Representing Event Codes**](#encodingEventCodes) for the description of the event code representation.
The [content items](#key-content-item) of an event are represented according to their datatype representations (see [Table 4-2](#table2)). In the absence of an associated datatype representation, attribute and character [*values*](#key-valueContentItem) are
represented as String ([**7.1.10 String**](#encodingString)).

[Definition:]EXI defines a minimal set of datatype representations called
**Built-in EXI datatype representations** that define how
[content items](#key-content-item)
as well as the parts of an [event code](#key-eventcode)
are represented in EXI streams.
When the [Preserve.lexicalValues](#key-preserveLexicalValuesOption) option is false,
[values](#key-valueContentItem) are represented using built-in EXI datatype representations
(see [**7.1 Built-in EXI Datatype Representations**](#encodingDatatypes)) or user-defined datatype representations
(see [**7.4 Datatype Representation Map**](#datatypeRepresentationMap)) associated with the schema
[datatypes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#datatype)XS2.
Otherwise,
[values](#key-valueContentItem)
are represented as Strings with restricted character sets (see [Table 7-2](#builtInRestrictedStrings) below).

The following [Table 7-1](#builtInEXITypes) lists the
built-in EXI datatype representations, associated
EXI datatype identifiers
and the XML Schema [built-in datatypes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#built-in-datatypes)XS2
each
EXI datatype representation
is used to represent by default.
When that default association is in effect, datatypes derived from the XML Schema datatypes are also represented according to the associated [built-in EXI datatype representation](#key-exidatatype).
When there are more than one XML Schema datatypes from which a datatype is derived directly or indirectly, the closest ancestor is used to determine the [built-in EXI datatype representation](#key-exidatatype). For example, a value of XML Schema datatype xsd:int is represented according to the same [built-in EXI datatype representation](#key-exidatatype) as a value of XML Schema datatype xsd:integer. Although xsd:int is derived indirectly from xsd:integer and also further from xsd:decimal, a value of xsd:int is processed as an instance of xsd:integer because xsd:integer is closer to xsd:int than xsd:decimal is in the datatype inheritance hierarchy.

Table 7-1.
Built-in EXI Datatype Representations

| Built-in EXI Datatype Representation | EXI Datatype ID | XML Schema Datatypes | |
| --- | --- | --- | --- |
| [Binary](#encodingBinary) | exi:base64Binary | *base64Binary* | |
| exi:hexBinary | *hexBinary* | |
| [Boolean](#encodingBoolean) | exi:boolean | *boolean* | |
| [Date-Time](#encodingDateTime) | exi:dateTime | *dateTime* | |
| exi:time | *time* | |
| exi:date | *date* | |
| exi:gYearMonth | *gYearMonth* | |
| exi:gYear | *gYear* | |
| exi:gMonthDay | *gMonthDay* | |
| exi:gDay | *gDay* | |
| exi:gMonth | *gMonth* | |
| [Decimal](#encodingDecimal) | exi:decimal | *decimal* | |
| [Float](#encodingFloat) | exi:double | *float*, *double* | |
| [Integer](#encodingInteger) | exi:integer | *integer* | |
| [String](#encodingString) | exi:string | *string*, *anySimpleType* and all types directly derived by *union* | |
| [n-bit Unsigned Integer](#encodingBoundedUnsigned) |  | Not associated with any datatype directly, but used by [Integer](#encodingInteger) datatype representation for some bounded *integers* (see [**7.1.5 Integer**](#encodingInteger)) | |
| [Unsigned Integer](#encodingUnsignedInteger) |  | Not associated with any datatype directly, but used by [Integer](#encodingInteger) datatype representation for unsigned *integers* (see [**7.1.5 Integer**](#encodingInteger)) | |
| [List](#encodingList) |  | All types directly derived by *list*, including *NMTOKENS*, *IDREFS* and *ENTITIES* | |
| [QName](#encodingQName) |  | xsi:type attribute values when [Preserve.lexicalValues](#key-preserveLexicalValuesOption) option value is *false* | |

Each EXI datatype identifier above is a [qname](#key-qname) that uniquely identifies one of the
[built-in EXI datatype representations.](#key-exidatatype)
EXI datatype identifiers are used in [Datatype Representation Maps](#key-datatypeRepresentationMaps) to
change
the datatype representations used for specific schema [datatypes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#datatype)XS2 and their sub-types.
Only [built-in EXI datatype representations](#key-exidatatype)
that have been assigned identifiers are usable in [Datatype Representation Maps](#key-datatypeRepresentationMaps).

When the [Preserve.lexicalValues](#key-preserveLexicalValuesOption) option is true, all
[*values*](#key-valueContentItem)
are represented as Strings.
The table below defines restricted character sets for several of the built-in EXI datatypes. Each [*value*](#key-valueContentItem) that would have otherwise been represented by one of these datatypes is instead represented as a String with the associated restricted character set,
regardless of the actual pattern facets, if any, specified in the definitions of the schema datatypes.

Table 7-2. Restricted Character Sets for Built-in EXI
Datatype Representations

| EXI Datatype ID | Restricted Character Set |
| --- | --- |
| exi:base64Binary | { #x9, #xA, #xD, #x20, +, /, [0-9], =, [A-Z], [a-z] } |
| exi:hexBinary | { #x9, #xA, #xD, #x20, [0-9], [A-F], [a-f] } |
| exi:boolean | { #x9, #xA, #xD, #x20, 0, 1, a, e, f, l, r, s, t, u } |
| exi:dateTime | { #x9, #xA, #xD, #x20, +, -, ., [0-9], :, T, Z } |
| exi:time |
| exi:date |
| exi:gYearMonth |
| exi:gYear |
| exi:gMonthDay |
| exi:gDay |
| exi:gMonth |
| exi:decimal | { #x9, #xA, #xD, #x20, +, -, ., [0-9] } |
| exi:double | { #x9, #xA, #xD, #x20, +, -, ., [0-9], E, F, I, N, a, e } |
| exi:integer | { #x9, #xA, #xD, #x20, +, -, [0-9] } |
| exi:string | *no restricted character set* |

The restricted character set for the EXI List datatype representation is the restricted character set of the EXI datatype representation of the List item type.

The restricted character set for a value that would be represented as an EXI enumeration is the restricted character set of the EXI datatype representation of the enumeration base type.

The rules used to represent values of String depend on the [content items](#key-content-item) to which the values belong. There are certain [content items](#key-content-item) whose value representation involve the use of string tables while other [content items](#key-content-item) are represented using the encoding rule described in [**7.1.10 String**](#encodingString) without involvement of string tables. The [content items](#key-content-item) that use string tables and how each of such [content items](#key-content-item) uses string tables to represent their values are described in [**7.3 String Table**](#stringTable).

Schemas can provide one or more enumerated values for
datatypes.
When the [Preserve.lexicalValues](#key-preserveLexicalValuesOption) option is false,
EXI exploits those pre-defined values when they are available to represent values of such
datatypes
in a more efficient manner than
would have done otherwise without using pre-defined values.
The encoding rule for representing
enumerated values
is described in [**7.2 Enumerations**](#encodingEnumerations).
Datatypes
that are directly derived from
another
by union and their subtypes are always represented as String regardless of the availability of enumerated values. Representation of values of which the
datatype is either a [list datatype](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#list-datatypes)XS2, or
one of QName, Notation or a
datatype
derived therefrom by restriction are also not affected by enumerated values if any.

### 7.1 Built-in EXI Datatype Representations

The following sections describe the [built-in EXI datatype representations](#key-exidatatype) used for representing
[event codes](#key-eventcode) and [content items](#key-content-item) in EXI streams. Unless otherwise stated, individual items in an EXI stream are packed into bytes most significant bit first.

#### 7.1.1 Binary

The Binary datatype representation is a length-prefixed sequence of octets representing the binary content. The length is represented as an Unsigned Integer (see
[**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)).

#### 7.1.2 Boolean

When the associated schema datatype is directly or indirectly derived from xsd:boolean and pattern facets are available in the schema datatype,
the Boolean datatype representation is a *n*-bit unsigned integer ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)), where *n* is two (2) and the values zero (0), one (1), two (2) and three (3) represent the values "false", "0", "true" and "1" respectively.

Otherwise,
the Boolean datatype representation is a *n*-bit unsigned integer ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)), where *n* is one (1). The value zero (0) represents false and the value one (1) represents true.

#### 7.1.3 Decimal

The Decimal datatype representation is a Boolean sign (see [**7.1.2 Boolean**](#encodingBoolean)) followed by two Unsigned Integers (see [**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)). A sign value of zero (0) is used to represent positive Decimal values and a sign value of one (1) is used to represent negative Decimal values. The first Unsigned Integer represents the integral portion of the Decimal value. The second Unsigned Integer represents the fractional portion of the Decimal value with the digits in reverse order to preserve leading zeros.

**Note:**

Some implementers may assume and try to find a parallel between Decimal
and [**7.1.5 Integer**](#encodingInteger) datatype representations. However, note that there are enough
discrepancies that may make sharing implementation codes between the two
more involved than some would have presumed. In particular [**7.1.5 Integer**](#encodingInteger)
cannot represent minus zero.

#### 7.1.4 Float

The Float datatype representation is two consecutive Integers (see
[**7.1.5 Integer**](#encodingInteger)). The first Integer represents the mantissa of the floating point number and the second Integer represents the base-10 exponent of the floating point number. The range of the mantissa is - (263) to 263-1 and the range of the exponent is - (214-1) to 214-1.
Mantissa or exponent values outside of the respective accepted range MUST NOT be used in the Float datatype representation. Values typed as Float with a mantissa or exponent outside the accepted range are represented as untyped values, processed by an alternative production if available that can be used to represent untyped values.
Examples of such productions are those whose terminal symbol on the right-hand side is AT(*qname*) [untyped value], AT(\*) [untyped value] or CH [untyped value] (See [**8.5.4.4.1 Adding Productions when Strict is False**](#addingProductions)).

The exponent value -(214) is used to indicate one of the special values: infinity, negative infinity and not-a-number (NaN). An exponent value -(214) with mantissa values 1 and -1 represents
positive infinity (INF) and negative infinity (-INF) respectively. An exponent value -(214) with any other mantissa value represents NaN.

The Float datatype representation can be decoded by going through the following steps.

1. Retrieve the mantissa value using the procedure described in [**7.1.5 Integer**](#encodingInteger).
2. Retrieve the exponent value using the procedure described in [**7.1.5 Integer**](#encodingInteger).
3. If the exponent value is -(214), the mantissa value 1 represents INF, the mantissa value -1 represents -INF and any other mantissa value represents NaN. If the exponent value is not -(214), the float value is *m* × 10*e* where *m* is the mantissa and *e* is the exponent obtained in the preceding steps.

#### 7.1.5 Integer

The Integer datatype representation supports signed integer numbers of arbitrary magnitude. The specific representation used depends on the [facet](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#dt-facet)XS2 values of the associated schema [datatype](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#datatype)XS2 as follows.

If the associated schema datatype is directly or indirectly derived from xsd:integer and the bounded range determined by its
[minInclusive](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#rf-minInclusive)XS2,
[minExclusive](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#rf-minExclusive)XS2,
[maxInclusive](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#rf-maxInclusive)XS2 and
[maxExclusive](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#rf-maxExclusive)XS2 facets has 4096 or fewer values,
the value is represented as an [n-bit Unsigned Integer](#encodingBoundedUnsigned) offset from the minimum value in the range where *n* is ⌈ log2 *m* ⌉ and *m* is the bounded range of the schema datatype.

Otherwise, if the associated schema datatype is directly or indirectly derived from xsd:integer and the [minInclusive](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#rf-minInclusive)XS2 or
[minExclusive](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#rf-minExclusive)XS2 facets specify a lower bound greater than or equal to zero (0), the value is represented as an [Unsigned Integer](#encodingUnsignedInteger).

Otherwise, the value is represented as a Boolean sign (see [**7.1.2 Boolean**](#encodingBoolean)) followed by an Unsigned Integer (see [**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)). A sign value of zero (0) is used to represent positive integers and a sign value of one (1) is used to represent negative integers. For non-negative values, the Unsigned Integer holds the magnitude of the value. For negative values, the Unsigned Integer holds the magnitude of the value minus 1.

#### 7.1.6 Unsigned Integer

The Unsigned Integer datatype representation supports unsigned integer numbers of arbitrary magnitude. It is represented as a sequence of octets terminated by an octet with its most significant bit set to 0. The value of the unsigned integer is stored in the least significant 7 bits of the octets as a sequence of 7-bit bytes, with the least significant byte first.

EXI processors SHOULD support arbitrarily large Unsigned Integer values. EXI processors MUST support Unsigned Integer values less than 2147483648.

The Unsigned Integer datatype representation can be decoded by going through the following steps.

*Example 7-1.
Example algorithm for decoding an Unsigned Integer*

1. Start with the initial value set to 0 and the initial multiplier set to 1.
2. Read the next octet.
3. Multiply the value of the unsigned number represented by the 7 least significant bits of the octet by the current multiplier and add the result to the current value.
4. Multiply the multiplier by 128.
5. If the most significant bit of the octet was 1, go back to step 2.

#### 7.1.7 QName

The QName datatype representation is a sequence of values representing the URI, local-name and prefix components of the QName in that order, where the prefix component is present only when the [Preserve.prefixes](#key-preservePrefixesOption) option is set to true.

When the QName value is specified by a schema-informed grammar using the SE (*qname*) or AT (*qname*) terminal symbols, URI and local-name are implicit and are omitted.
Similarly, when the URI of the QName value is derived from a schema-informed grammar using
SE (*uri*: \*)
or AT (*uri*: \*)
terminal symbols, URI is implicit thus omitted in the representation, and only the local-name component is encoded as a String (see [**7.1.10 String**](#encodingString)).
Otherwise, URI and local-name components are encoded as Strings.
If the QName is in no namespace, the URI is represented by a zero length String.

When present, prefixes are represented as *n*-bit unsigned integers ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)), where *n* is
⌈ log2(*N*) ⌉
and *N* is the number of *prefix*es in the prefix string table partition associated with the URI of the QName or one (1) if there are no prefixes in this partition.
If the given *prefix* exists in the associated prefix string table partition, it is represented using the compact identifier assigned by the partition. If the given *prefix* does not exist in the associated partition, the QName MUST be part of an SE event and the prefix MUST be resolved by one of the NS events immediately following the SE event (see resolution rules below). In this case, the unresolved prefix representation is not used and can be zero (0) or the compact identifier of any prefix in the associated partition.

**Note:**

When *N* is one, the prefix is represented using zero bits (i.e. omitted).

Given a *n*-bit unsigned integer *m* that represents either the prefix value or an unresolved prefix value, the effective prefix value is determined by following the rules described below in order. A QName is in error if its prefix cannot be resolved by the rules below.

1. If the prefix string table partition associated with the URI of the QName assigns the compact identifier *m* to a *prefix* value, select this *prefix* value as the candidate *prefix* value. Otherwise, there is no candidate *prefix* value.
2. If the QName value is part of an SE event followed by an associated NS event with
   its [*local-element-ns*](#key-indicatorContentItem) flag value
   set to true, the *prefix* value is the *prefix* of this NS event. Otherwise, the *prefix* value is the candidate value, if any, selected in step 1 above.

#### 7.1.8 Date-Time

The Date-Time datatype representation is a sequence
of values representing the individual components of the Date-Time. The
following table specifies each of the possible date-time components
along with how they are encoded. The value ranges of the date-time components follow the
definitions of the XML Schema specification [[XML Schema Datatypes]](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/) which for example prescribes the value range of the seconds to be between 0 and 60 to account for leap second representation and hour between 0 and 24 among others.

Table 7-3. Date-Time components

| Component | Value | Type |
| --- | --- | --- |
| Year | Offset from 2000 | Integer ( [**7.1.5 Integer**](#encodingInteger)) |
| MonthDay | Month \* 32 + Day | 9-bit Unsigned Integer ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)) where day is a value in the range 1-31 and month is a value in the range 1-12. |
| Time | ((Hour \* 64) + Minutes) \* 64 + seconds | 17-bit Unsigned Integer ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)) where Hour is a value in the range 0-24, Minutes is a value in the range 0-59 and seconds is a value in the range 0-60 |
| FractionalSecs | Fractional seconds | Unsigned Integer ( [**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)) representing the fractional part of the seconds with digits in reverse order to preserve leading zeros |
| TimeZone | TZHours \* 64 + TZMinutes | 11-bit Unsigned Integer ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)) representing a signed integer offset by 896 ( = 14 \* 64 ) where TZHours is a value in the range [-14 .. 14] and TZMinutes is a value in the range [-59 .. 59] |
| presence | Boolean presence indicator | Boolean ([**7.1.2 Boolean**](#encodingBoolean)) |

The variety of components that constitute a value and their appearance order depend on the XML Schema type associated with the value. The following table shows which components are included in a value of each XML Schema type that is relevant to Date-Time datatype. Items listed in square brackets are included if and only if the value of its preceding presence indicator (specified above) is set to true.

Table 7-4. Assortment of Date-Time components

| XML Schema Datatype | Included Components |
| --- | --- |
| [gYear](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#gYear)XS2 | Year, presence, [TimeZone] |
| [gYearMonth](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#gYearMonth)XS2 | Year, MonthDay, presence, [TimeZone] |
| [date](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#date)XS2 |
| [dateTime](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#dateTime)XS2 | Year, MonthDay, Time, presence, [FractionalSecs], presence, [TimeZone] |
| [gMonth](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#gMonth)XS2 | MonthDay, presence, [TimeZone] |
| [gMonthDay](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#gMonthDay)XS2 |
| [gDay](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#gDay)XS2 |
| [time](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#time)XS2 | Time, presence, [FractionalSecs], presence, [TimeZone] |

#### 7.1.9 *n*-bit Unsigned Integer

When the value of the [compression option](#key-compressionOption) is false and
the [bit-packed](#key-unaligned) alignment is used,
the *n*-bit Unsigned Integer datatype representation is an unsigned binary integer using *n* bits.
Otherwise, it is an unsigned integer using the minimum number of bytes required to store
*n* bits. Bytes are ordered with the least significant byte first.

The *n*-bit unsigned integer is used for representing [event codes](#key-eventcode), the prefix component of QNames (see [**7.1.7 QName**](#encodingQName)) and certain [*value*](#key-valueContentItem) content items, as described in respective relevant parts of this document. As described in section [**7.1.5 Integer**](#encodingInteger), integers with a bounded range size *m* equal to
4096
or smaller are represented as *n*-bit unsigned integers with *n* being ⌈ log 2 *m* ⌉, as an offset from the minimum value in the range.

#### 7.1.10 String

The String datatype representation is a length prefixed sequence of
characters. The length indicates the number of characters in the
string and is represented as an Unsigned Integer (see [**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)). If a restricted character set is defined for the string (see [**7.1.10.1 Restricted Character Sets**](#restrictedCharSet)), each character is represented as an *n*-bit Unsigned Integer (see [**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)). Otherwise, each character is represented by its Unicode
[[UNICODE]](#Unicode)
code point encoded as an Unsigned Integer (see [**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)).

EXI uses a string table to represent certain
[content items](#key-content-item) more efficiently. Section [**7.3 String Table**](#stringTable)
describes the string table and how it is applied to different content
items.

##### 7.1.10.1 Restricted Character Sets

If a string value is associated with a schema [datatype](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#datatype)XS2
directly or indirectly derived from xsd:string and one or more of the datatypes in its datatype hierarchy has one or more pattern facets, there may be a restricted character set defined for the string value. The following steps are used to determine the restricted character set, if any, defined for a given string value associated with such a schema datatype.

Given the schema datatype, let the target datatype definition be the definition of the most-derived datatype that has one or more pattern facets immediately specified in its definition in the schema among those in the datatype inheritance hierarchy that traces backwards toward [primitive datatypes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#dt-primitive)XS2 starting from the datatype.
If the target datatype definition is a definition for a [built-in datatype](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#dt-derived)XS2, there is no restricted character set for the string value. Otherwise,
determine the set of characters for each immediate pattern facet of the target datatype definition according to section [**E Deriving
Set of Characters
from XML Schema Regular Expressions**](#regexToCharset).
Then, compute the restricted set of characters for the string value as the union of all the sets of characters computed in the previous step. If the resulting set of characters contains less than
256
characters and contains only BMP characters, the string value has a restricted character set and each character is represented using an *n*-bit Unsigned Integer (see [**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)), where *n* is ⌈ log2(*N* + 1) ⌉ and *N* is the number of characters in the restricted character set.

The characters in the restricted character set are sorted by Unicode [[UNICODE]](#Unicode) code point and represented by integer values in the range (0 ... *N*−1) according to their ordinal position in the set. Characters that are not in this set are represented by the *n*-bit Unsigned Integer *N* followed by the Unicode code point of the character represented as an Unsigned Integer.

The figure below illustrates an overview of the process for determining and using restricted character sets described in this section.

![String Processing Model](restrictedCharset.png)

*Figure 7-1. String Processing Model*

#### 7.1.11 List

Values of type List are encoded as a length
prefixed sequence of values. The length is encoded as an Unsigned Integer (see
[**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)) and each value is encoded according
to its type (see [**7. Representing Event Content**](#encodingValues)).

### 7.2 Enumerations

When the [Preserve.lexicalValues](#key-preserveLexicalValuesOption) option is false,
enumerated values
are encoded as
*n*-bit Unsigned Integers ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)) where *n* = ⌈ log 2 *m* ⌉ and *m* is the number of items
in the enumerated type. The unsigned integer value assigned to each item corresponds to
its ordinal position in the enumeration in schema-order starting with
position zero (0).
When there are more than one item that represent the same value in the enumeration,
such value can be represented using the ordinal position of any items that represent the value.

Exceptions are for schema [union datatypes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#union-datatypes)XS2 , [list datatypes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#list-datatypes)XS2, as well as QName or Notation and types derived therefrom by restriction. The values of such types are processed by their respective built-in EXI datatype representations instead of being represented as enumerations.

### 7.3 String Table

EXI uses a string table to assign "compact identifiers" to some
string values. Occurrences of string values found in the string table
are represented using the associated compact identifier rather than
encoding the entire "string literal". The string table is initially pre-populated with
string values that are likely to occur in certain contexts and is
dynamically expanded to include additional string values encountered
in the document. The following [content items](#key-content-item) are encoded using a
string table:

* [*uris*](#key-uriContentItem)
* [*prefixes*](#key-prefixContentItem)
* *uri* and
  *local-name*
  in [*qnames*](#key-qnameContentItem)
* [*values*](#key-valueContentItem)

When a string value is found in the string table, the value is encoded
using the compact identifier and no changes are made to the string table as a result.
When a string value is not found in the string table, its string literal is encoded
as a String without using a compact identifier, only after which
the string table is augmented by including the string value with an assigned
compact identifier
unless the string value represents a [*value*](#key-valueContentItem) content item
and fails to satisfy the criteria in effect by virtue of [valuePartitionCapacity](#key-valuePartitionCapacityOption) and [valueMaxLength](#key-valueMaxLengthOption) options
.

The string table is divided into partitions and each partition is
optimized for more frequent use of either compact identifiers or string literals
depending on the purpose of the partition. Section [**7.3.1 String Table Partitions**](#stringTablePartitions) describes how EXI string table is
partitioned. Section [**7.3.2 Partitions Optimized for Frequent use of Compact Identifiers**](#encodingOptimizedForHits)
describes how string values are encoded when the associated partition
is optimized for more frequent use of compact identifiers. Section [**7.3.3 Partitions Optimized for Frequent use of String Literals**](#encodingOptimizedForMisses) describes how string values are
encoded when the associated partition is optimized for more frequent use
of string literals.

The life cycle of a string table spans the processing of
a single EXI stream. String tables are not represented in an EXI stream or exchanged
between EXI processors. A string table cannot be reused across multiple EXI streams;
therefore, EXI processors MUST use a string table that is equivalent to
the one that would have been newly created and pre-populated with initial
values for processing each EXI stream.

#### 7.3.1 String Table Partitions

The string table is organized into partitions
so that the indices assigned to compact identifiers can stay relatively small.
Smaller number of indices results in improved average compactness and the efficiency
of table operations. Each partition has a separate set of compact identifiers and
[content items](#key-content-item) are assigned to specific partitions as described below.

[*Uri*](#key-uriContentItem) content items and the URI portion of
[*qname*](#key-qnameContentItem) content items are assigned to the uri
partition. The uri partition is optimized for frequent use of compact identifiers and is
pre-populated with initial entries as described in [**D.1 Initial Entries in Uri Partition**](#initialUriValues).
When a schema is provided, the uri partition is also pre-populated with
the name of each
target
namespace URI declared in the schema,
plus some of the namespace URIs used in wildcard terms
and attribute wildcards
(see section [**8.5.4.1.7 Wildcard Terms**](#wildcardTerms)
and [**8.5.4.1.3.2 Complex Type Grammars**](#complexTypeGrammars), respectively
for the condition),
appended in lexicographical order.

[*Prefix*](#key-prefixContentItem) content items are assigned to partitions based
on their associated namespace URI. Partitions containing
*prefix* content items are optimized for frequent use of compact identifiers and the
string table is pre-populated with entries as described in
[**D.2 Initial Entries in Prefix Partitions**](#initialPrefixValues).

The local-name portion of [*qname*](#key-qnameContentItem)
content items are assigned to partitions based on the namespace URI of
the *qname* content item of which the local-name is a part.
Partitions containing local-names are optimized for frequent use of string
literals and the string table is pre-populated with entries as described in
[**D.3 Initial Entries in Local-Name Partitions**](#initialLocalNames).

Each [*value*](#key-valueContentItem)
content item is assigned to both the global value partition
and a "local" value partition based on the
[qname](#key-qname)
of the attribute or element in context at the time
the value is added to the value partitions.
Partitions containing [*value*](#key-valueContentItem) content items are optimized for frequent use of string literals and are initially empty.
[Definition:]
The variable ***globalID*** is a non-negative integer representing the compact identifier of the next item added to the global value partition.
Its value is initially set to 0 (zero) and changes while processing an EXI stream per the rule described in [**7.3.3 Partitions Optimized for Frequent use of String Literals**](#encodingOptimizedForMisses).

#### 7.3.2 Partitions Optimized for Frequent use of Compact Identifiers

String table partitions that are expected to contain a relatively
small number of entries used repeatedly throughout the document are
optimized for the frequent use of compact identifiers. This includes the [*uri*](#key-uriContentItem) partition and
all partitions containing [*prefix*](#key-prefixContentItem) content items.

When a string value is found in a partition optimized for frequent use of compact identifiers,
the string value is represented as the value (*i*+1)
encoded as an *n*-bit Unsigned Integer ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)), where
*i* is the value of the compact identifier, *n* is
⌈ log2 (*m*+1) ⌉ and *m* is the number of
entries in the string table partition at the time of the operation.

When a string value is not found in a partition optimized for frequent use of compact identifiers,
the String value is represented as zero (0) encoded as an
*n*-bit Unsigned Integer, followed by the string literal
encoded as a String ([**7.1.10 String**](#encodingString)). After
encoding the String value, it is added to the string table partition
and assigned the next available compact identifier *m*.

#### 7.3.3 Partitions Optimized for Frequent use of String Literals

The remaining string table partitions are optimized for
the frequent use of string literals. This includes all string table partitions containing
local-names
and all string table partitions containing [*value*](#key-valueContentItem) content
items.

When a string value is found in the partitions containing
local-names, the
string value is represented as zero (0) encoded as an Unsigned Integer (see
[**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)) followed by
the compact identifier of the string value. The compact identifier of the string
value is encoded as an *n*-bit unsigned integer ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)), where
*n* is ⌈ log2 *m* ⌉ and *m* is
the number of entries in the string table partition at the time of the operation.

When a string value is not found in the partitions containing
local-names, its
string literal is encoded as a String (see [**7.1.10 String**](#encodingString)) with the length of the string incremented
by one. After encoding the string value, it is added to the string
table partition and assigned the next available compact
identifier *m*.

As described above, each [*value*](#key-valueContentItem) content item is assigned
to two partitions, a "local" value partition and the global
value partition.
When a string value is found in the global or "local" partition, it is represented using a compact identifier. When a string value is found in the "local" value partition,
the string value may be represented as zero (0) encoded as an Unsigned Integer (see
[**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)) followed by the compact identifier
of the string value in the "local" value partition.
When a string value is found in the global value partition, the String value may be represented as one (1) encoded as an
Unsigned Integer (see [**7.1.6 Unsigned Integer**](#encodingUnsignedInteger)) followed by the compact
identifier of the String value in the global value
partition. The compact identifier is encoded as an *n*-bit
unsigned integer ([**7.1.9 n-bit Unsigned Integer**](#encodingBoundedUnsigned)), where *n* is ⌈ log2*m* ⌉ and *m* is the number of entries in the
associated partition at the time of the operation.

When a string value *S* is not found in the global or "local"
*value* partition, its string literal is encoded as a
String (see [**7.1.10 String**](#encodingString)) with the length
*L* + 2 (incremented by two) where *L* is the number of characters in the string value.
If [valuePartitionCapacity](#key-valuePartitionCapacityOption) is not zero, and
*L* is greater than zero and no more than [valueMaxLength](#key-valueMaxLengthOption), the string *S* is added to the associated "local" value partition using the next available compact identifier *m* and added to the global value partition using the compact identifier [*globalID*](#key-globalID). When *S* is added to the global value partition and there was already a string *V* in the global value partition associated with the compact identifier [*globalID*](#key-globalID), the string *S* replaces the string *V* in the global table, and the string *V* is removed from its associated local value partition by rendering its compact identifier permanently unassigned. When the string value is added to the global value partition, the value of [*globalID*](#key-globalID) is incremented by one (1). If the resulting value of [*globalID*](#key-globalID) is equal to [valuePartitionCapacity](#key-valuePartitionCapacityOption), its value is reset to zero (0)

### 7.4 Datatype Representation Map

By default, each typed value in an EXI stream is represented using its
default built-in EXI datatype representation (see [Table 7-1](#builtInEXITypes)).
However, [Definition:][EXI processors](#key-exiprocessor) MAY provide the capability to specify alternate built-in EXI datatype representations or
user-defined datatype representations for specific schema
[datatypes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#datatype)XS2.
This capability is called a **Datatype Representation Map**.

**Note:**

This feature is relevant only to simple types in the schema.
EXI does not provide a way for applications to infuse custom representations of structured data bound to complex types into the format.

EXI processors that support Datatype Representation Maps MAY provide implementation specific means to define and install user-defined datatype representations. EXI processors MAY also provide implementation specific means for applications or users to specify alternate built-in EXI datatype representations or user-defined datatype representations for representing specific schema datatypes. As with the default EXI datatype representations, alternate datatype representations are used for the associated XML Schema types specified in the Datatype Representation Map and XML Schema datatypes derived from those datatypes. When there are built-in or user-defined datatype representations associated with more than one XML Schema datatype in the type hierarchy of a particular datatype, the closest ancestor with an associated datatype representation is used to determine the EXI datatype representation. For XML Schema datatypes with enumerated values, the encoding rule described in [**7.2 Enumerations**](#encodingEnumerations) is used as the representation when the closest ancestor datatype with an associated datatype representation has no enumerated values.

When an EXI processor encodes an EXI stream using
a Datatype Representation Map and the [EXI Options](#key-options) part of the header is present, the EXI options part MUST specify all alternate datatype representations used in the EXI stream.
An EXI processor that attempts to decode an
EXI stream that specifies a user-defined datatype representation in the EXI header that
it does not recognize MAY report a warning, but this is not an
error. However, when an EXI processor encounters a typed value that
was encoded by a user-defined datatype representation that it does not support, it MUST
report an error.

The EXI options header, when it appears in an EXI stream, MUST include a
"datatypeRepresentationMap" element for each
schema datatype
of which the descendant datatypes derived by restriction as well as itself are
not represented using the default
built-in EXI datatype representation.
The "datatypeRepresentationMap" element includes two child elements.
The [qname](#key-qname) of
the first child element identifies the schema datatype that is not
represented using the default
built-in EXI datatype representation
and the [qname](#key-qname) of the
second child element identifies the alternate
built-in EXI datatype representation or user-defined datatype representation
used to represent that type.
Built-in EXI datatype representations are identified by the type identifiers in
[Table 7-1](#builtInEXITypes).

For example, the following "datatypeRepresentationMap" element indicates all values of
type xsd:decimal are represented using the built-in exi:string datatype representation. In addition, all datatypes directly or indirectly derived from xsd:decimal by restriction that do not have a closer ancestor in the type hierarchy with an associated datatype representation are represented using exi:string.

*Example 7-2. datatypeRepresentationMap indicating all Decimal values are represented using
built-in String datatype representation*

```

    <exi:datatypeRepresentationMap xmlns:xsd="http://www.w3.org/2001/XMLSchema">
        <xsd:decimal/>
        <exi:string/>
    </exi:datatypeRepresentationMap>
```

It is the responsibility of an EXI processor to interface with a particular implementation of
built-in EXI datatype representations
or user-defined
datatype representations
properly. In the example above, an EXI processor may need to provide a string value of the data being processed that is typed as xsd:decimal in order to interface with
an implementation of built-in String datatype representation.
In such a case, some EXI processors may have started with a decimal value and such processors may well translate the value into a string before passing the data to
the implementation of built-in String datatype representation
while other EXI processors may already have a string value of the data so that it can pass the value directly to
the implementation of built-in String datatype representation
without any translation.

As another example, the following
"datatypeRepresentationMap" element indicates all
values of the user-defined
simple type
geo:geometricSurface
and the datatypes derived from it by restriction
are represented
using the user-defined datatype representation geo:geometricInterpolator:

*Example 7-3. datatypeRepresentationMap illustrating a user-defined type represented by a user-defined datatype representation*

```

    <exi:datatypeRepresentationMap xmlns:geo="http://example.com/Geometry">
        <geo:geometricSurface/>
	<geo:geometricInterpolator/>
    </exi:datatypeRepresentationMap>
```

**Note:**

EXI only defines a way to indicate the use of user-defined datatype representations for representing values of specific datatypes.
Datatype representations are referred to by their respective [qnames](#key-qname) in "datatypeRepresentationMap" elements. A datatype representation is omnipresent only if its [qname](#key-qname) is one of those that represent built-in EXI datatype representations.
For datatype representations of other [qnames](#key-qname), EXI does not provide nor suggest a method by which they are identified and shared between EXI Processors.
This suggests that the use of user-defined (i.e. custom) datatype representations
needs to be restrained by weighing alternatives and considering the consequences of each in pros and cons, in order to avoid unruly proliferation of documents that use such datatype representations.
Those applications that ever find Datatype Representation Map useful should make sure that they exchange such documents only among the parties that are pre-known or discovered to be able to process the user-defined datatype representations that are in use. Otherwise, if it is not for certain if a receiver understands the particular user-defined datatype representations, the sender should never attempt to send documents that use user-defined datatype representations to that recipient.

## 8. EXI Grammars

EXI is a knowledge based encoding that uses a set of grammars to
determine which events are most likely to occur at any given point in
an EXI stream and encodes the most likely alternatives in fewer
bits. It does this by mapping the stream of events to a lower entropy
set of representative values and encoding those values using a set of
simple variable length codes or an EXI compression algorithm.

The result is a very simple, small algorithm that uniformly handles
schema-less encoding, schema-informed encoding, schema deviations,
and any combination thereof in EXI streams. These variations do
not require different algorithms or different parsers, they are simply
informed by different combinations of grammars.

The following sections describe the grammars used to inform the EXI encoding.

**Note:**

The grammar semantics in this specification are written for clarity and generality. They do not prescribe a particular implementation approach.

### 8.1 Grammar Notation

#### 8.1.1 Fixed Event Codes

Each grammar production has an [event code](#key-eventcode), which is represented by a sequence of one to three parts separated by periods ("."). Each part is an unsigned integer. The following are examples of grammar productions with [event codes](#key-eventcode) as they appear in this specification.

*Example 8-1. Example productions with fixed event codes*

|  | | | |
| --- | --- | --- | --- |
|  | Productions | | Event Codes |
|  | | | |
|  | *LeftHandSide*1 : | | |
|  |  | Terminal1    *NonTerminal*1 | 0 |
|  |  | Terminal2    *NonTerminal*2 | 1 |
|  |  | Terminal3    *NonTerminal*3 | 2.0 |
|  |  | Terminal4    *NonTerminal*4 | 2.1 |
|  |  | Terminal5    *NonTerminal*5 | 2.2.0 |
|  |  | Terminal6    *NonTerminal*6 | 2.2.1 |
|  | | | |
|  | *LeftHandSide*2 : | | |
|  |  | Terminal1    *NonTerminal*1 | 0 |
|  |  | Terminal2    *NonTerminal*2 | 1.0 |
|  |  | Terminal3    *NonTerminal*3 | 1.1 |

The number of parts in a given [event code](#key-eventcode) is called the event code's length. No two productions with the same non-terminal symbol on the left-hand side are permitted to have the same [event code](#key-eventcode).

#### 8.1.2 Variable Event Codes

Some non-terminal symbols are used on the right-hand side in a production without
a terminal symbol prefixed to them, but with a parenthesized event code affixed instead.
Such non-terminal symbols are macros and they are used to capture some recurring set of productions
as
symbols so that a symbol can be used in the grammar representation instead of including all the productions the macro represents in place every time it is used.

*Example 8-2. Example productions that use macro non-terminal symbols*

|  | | | |
| --- | --- | --- | --- |
|  | *ABigProduction*1 : | | |
|  |  | Terminal1    *NonTerminal*1 | 0 |
|  |  | Terminal2    *NonTerminal*2 | 1 |
|  |  | *LEFTHANDSIDE 1* (2.0) | 2.0 |
|  | | | |
|  | *ABigProduction*2 : | | |
|  |  | Terminal1    *NonTerminal*1 | 0 |
|  |  | *LEFTHANDSIDE 1* (1.1) | 1.1 |
|  |  | Terminal2    *NonTerminal*2 | 1.2 |

Because non-terminal macros are injected into the right-hand side of more than one production,
the [event codes](#key-eventcode) of productions with these macro non-terminals on the left-hand side are not fixed, but will have different event code values depending on the context in which the macro non-terminal appears. This specification calls these variable event codes and uses variables in place of individual event code parts to indicate the event code parts are determined by the context. Below are some examples of variable event codes:

*Example 8-3. Example non-terminal macros and its productions with variable event codes*

|  | | | |
| --- | --- | --- | --- |
|  | *LEFTHANDSIDE*1*(n.m)* : | | |
|  |  | TERMINAL1   *NONTERMINAL*1 | *n*.0 |
|  |  | TERMINAL2   *NONTERMINAL*2 | *n*.1 |
|  |  | TERMINAL3   *NONTERMINAL*3 | *n*. *m*+2 |
|  |  | TERMINAL4   *NONTERMINAL*4 | *n*. *m*+3 |
|  |  | TERMINAL5   *NONTERMINAL*5 | *n*. *m*+4.0 |
|  |  | TERMINAL6   *NONTERMINAL*6 | *n*. *m*+4.1 |

Unless otherwise specified, the variable
*n* evaluates to the first part of the
[event code](#key-eventcode) of the production in which the macro non-terminal
*LEFTHANDSIDE*1 appears on the right-hand side. Similarly, the expression
*n*.
*m* represents the first two parts of the [event code](#key-eventcode) of the production in which the macro non-terminal
*LEFTHANDSIDE*1 appears on the right-hand side.

Non-terminal macros are used in this specification for notational convenience only.
They are not non-terminals, even though they are used in place of non-terminals.
Productions that use non-terminal macros on the right-hand side need to be expanded by macro substitution before such productions are interpreted.
Therefore, *ABigProduction*1 and *ABigProduction*2 shown in the preceding example are equivalent to the following set of productions obtained by expanding the non-terminal macro symbol *LEFTHANDSIDE*1 and evaluating the variable event codes.

*Example 8-4. Expanded productions equivalent to the productions used above*

|  | | | |
| --- | --- | --- | --- |
|  | *ABigProduction*1 : | | |
|  |  | Terminal1    *NonTerminal*1 | 0 |
|  |  | Terminal2    *NonTerminal*2 | 1 |
|  |  | TERMINAL1   *NONTERMINAL*1 | 2.0 |
|  |  | TERMINAL2   *NONTERMINAL*2 | 2.1 |
|  |  | TERMINAL3   *NONTERMINAL*3 | 2.2 |
|  |  | TERMINAL4   *NONTERMINAL*4 | 2.3 |
|  |  | TERMINAL5   *NONTERMINAL*5 | 2.4.0 |
|  |  | TERMINAL6   *NONTERMINAL*6 | 2.4.1 |
|  | | | | |
|  | *ABigProduction*2 : | | | |
|  |  | Terminal1    *NonTerminal*1 | 0 |
|  |  | TERMINAL1   *NONTERMINAL*1 | 1.0 |
|  |  | TERMINAL2   *NONTERMINAL*2 | 1.1 |
|  |  | Terminal2    *NonTerminal*2 | 1.2 |
|  |  | TERMINAL3   *NONTERMINAL*3 | 1.3 |
|  |  | TERMINAL4   *NONTERMINAL*4 | 1.4 |
|  |  | TERMINAL5   *NONTERMINAL*5 | 1.5.0 |
|  |  | TERMINAL6   *NONTERMINAL*6 | 1.5.1 |

### 8.2 Grammar Event Codes

Each production rule in the EXI grammar includes an [event code](#key-eventcode) value that approximates the likelihood the associated production rule will be matched over the other productions with the same left-hand-side non-terminal symbol. Ultimately, the [event codes](#key-eventcode) determine the value(s) by which each non-terminal symbol will be represented in the EXI stream.

To understand how a given [event code](#key-eventcode) approximates the likelihood a given production will match, it is useful to visualize the [event codes](#key-eventcode) for a set of production rules that have the same non-terminal symbol on the left-hand side as a tree. For example, the following set of productions:

*Example 8-5. Example productions with event codes*

|  |  |  |  |  |
| --- | --- | --- | --- | --- |
|  | *ElementContent* : | | | |
|  |  | EE | 0 |
|  |  | SE (\*)  *ElementContent* | 1.0 |
|  |  | CH  *ElementContent* | 1.1 |
|  |  | ER  *ElementContent* | 1.2 |
|  |  | CM  *ElementContent* | 1.3.0 |
|  |  | PI  *ElementContent* | 1.3.1 |

represents a set of information items that might occur as element content after the start tag. Using the production [event codes](#key-eventcode), we can visualize this set of productions as follows:

![Event code tree for ElementContent grammar](eventCodeTree.png)

*Figure 8-1. Event code tree for ElementContent grammar*

where the
terminal symbols
are represented by the leaf nodes of the tree, and the [event code](#key-eventcode) of each production rule
defines a path from the root of the tree to the node
that represents the terminal symbol that is on the right-hand side of the production.
We call this the event code tree for a given set of productions.

An event code tree is similar to a Huffman tree [[Huffman Coding]](#huffman) in that shorter paths are generally used for symbols that are considered more likely. However, event code trees are far simpler and less costly to compute and maintain. Event code trees are shallow and contain at most three levels. In addition, the length of each [event code](#key-eventcode) in the event code tree is assigned statically without analyzing the data. This classification provides some of the benefits of a Huffman tree without the cost.

### 8.3 Pruning Unneeded Productions

As discussed in section
[**6.3 Fidelity Options**](#fidelityOptions), applications MAY provide a set of fidelity options to specify the XML features they require. EXI processors MUST use these fidelity options to prune
the productions of which the terminal symbols represent the events that are not required from the grammars,
improving compactness and processing efficiency.

For example, the following set of productions represent the set of information items that might occur as element content after the start tag.

*Example 8-6. Example productions with full fidelity*

|  |  |  |  |
| --- | --- | --- | --- |
|  | *ElementContent* : | | |
|  |  | EE | 0 |
|  |  | SE (\*)  *ElementContent* | 1.0 |
|  |  | CH  *ElementContent* | 1.1 |
|  |  | ER  *ElementContent* | 1.2 |
|  |  | CM  *ElementContent* | 1.3.0 |
|  |  | PI  *ElementContent* | 1.3.1 |

If an application sets the fidelity options Preserve.comments, Preserve.pis and Preserve.dtd to false, the productions matching comment (CM), processing instruction (PI) and entity reference (ER) events are pruned from the grammar, producing the following set of productions:

*Example 8-7. Example productions after pruning*

|  |  |  |  |  |
| --- | --- | --- | --- | --- |
|  | *ElementContent* : | | | |
|  |  | EE | 0 |
|  |  | SE (\*)  *ElementContent* | 1.0 |
|  |  | CH  *ElementContent* | 1.1 |

Removing these productions from the grammar tells EXI processors that comments and processing instructions will never occur in the EXI stream, which reduces the entropy of the stream allowing it to be encoded in fewer bits.

Each time a production is removed from a grammar, the [event codes](#key-eventcode) of the other productions with the same non-terminal symbol on the left-hand side MUST be adjusted to keep them contiguous if its removal has left the remaining productions with non-contiguous event codes.

### 8.4 Built-in XML Grammars

This section describes the built-in XML grammars used by EXI when no schema information is available or when available schema information describes only portions of the EXI stream.

The built-in XML grammars are dynamic and continuously evolve to reflect knowledge learned while processing an EXI stream. New [built-in element grammars](#key-builtin-elem-grammar) are created to describe the content of newly encountered elements and new grammar productions are added to refine existing built-in grammars. Newly learned grammars and productions are used to more efficiently represent subsequent events in the EXI stream. All newly created [built-in element grammars](#key-builtin-elem-grammar) are [global element grammars](#key-global-element-grammar).

[Definition:]A **global element grammar** is a grammar describing the content of an element that has global scope (i.e. a global element). At the onset of processing an EXI stream, the set of global element grammars is the set of all schema-informed element grammars derived from element declarations that have a {scope} property of *global*. Each [built-in element grammar](#key-builtin-elem-grammar) created while processing an EXI stream is added to the set of global element grammars. Each global element
grammar
has a unique [qname](#key-qname).

#### 8.4.1 Built-in Document Grammar

In the absence of schema information describing the content of the EXI stream, the following grammar describes the events that will occur in an [EXI document](#key-exidocument).

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  | | | |
|  | *Document* : | | |
|  |  | SD *DocContent* | 0 |
|  | | | |
|  | *DocContent* : | | |
|  |  | SE (\*) *DocEnd* | 0 |
|  |  | DT *DocContent* | 1.0 |
|  |  | CM *DocContent* | 1.1.0 |
|  |  | PI *DocContent* | 1.1.1 |
|  | | | |
|  | *DocEnd* : | | |
|  |  | ED | 0 |
|  |  | CM *DocEnd* | 1.0 |
|  |  | PI *DocEnd* | 1.1 |

| Semantics: | |
| --- | --- |
|  |  |
|  | All productions in the built-in document grammars of the form *LeftHandSide* : SE (\*) *RightHandSide* are evaluated as follows:   1. Let *qname* be the [qname](#key-qname) of the element matched by SE (\*) 2. If a [global element grammar](#key-global-element-grammar) does not exist for element *qname*, create one according to section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars). 3. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname*. 4. Evaluate the remainder of event sequence using *RightHandSide*. |

#### 8.4.2 Built-in Fragment Grammar

In the absence of schema information describing the contents of an EXI stream, the following grammar describes the events that may occur in an [EXI fragment](#key-exifragment). The grammar below represents the initial set of productions in the built-in fragment grammar at the start of EXI stream processing. The associated semantics explain how the built-in fragment grammar evolves to more efficiently represent subsequent events in the EXI stream.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  | | | |
|  | *Fragment* : | | |
|  |  | SD *FragmentContent* | 0 |
|  | | | |
|  | *FragmentContent* : | | |
|  |  | SE (\*) *FragmentContent* | 0 |
|  |  | ED | 1 |
|  |  | CM *FragmentContent* | 2.0 |
|  |  | PI *FragmentContent* | 2.1 |

| Semantics: | |
| --- | --- |
|  |  |
|  | All productions in the built-in fragment grammars of the form *LeftHandSide* : SE (\*) *RightHandSide* are evaluated as follows:   1. Let *qname* be the [qname](#key-qname) of the element matched by SE (\*) 2. If a [global element grammar](#key-global-element-grammar) does not exist for element *qname*, create one according to section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars). 3. Create a production of the form *LeftHandSide* : SE (*qname*) *RightHandSide* with an [event code](#key-eventcode) 0 4. Increment the first part of the [event code](#key-eventcode) of each production in the current grammar with the non-terminal *LeftHandSide* on the left-hand side 5. Add the production created in step    3    to the grammar 6. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname*. 7. Evaluate the remainder of event sequence using *RightHandSide*.   All productions of the form *LeftHandSide* : SE (*qname*) *RightHandSide* that were previously added to the grammar upon the first occurrence of the element that has the [qname](#key-qname) *qname* are evaluated as follows when they are matched:   1. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname* 2. Evaluate the remainder of event sequence using *RightHandSide*. |

#### 8.4.3 Built-in Element Grammar

[Definition:]When no grammar exists for an element occurring in an EXI stream, a **built-in element grammar** is created for that element.
Built-in element grammars are initially generic and are progressively refined as the specific content for the associated element is learned. All built-in element grammars are [global element grammar](#key-global-element-grammar)s and can be uniquely identified by the qname of the global element they describe. At the outset of processing an EXI stream, the set of built-in element grammars is empty.

Below is the initial set of productions used for all newly created [built-in element grammars](#key-builtin-elem-grammar). The semantics describe how productions are added to each [built-in element grammar](#key-builtin-elem-grammar) as the content of the associated element is learned.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  | | | |
|  | *StartTagContent* : | | |
|  |  | EE | 0.0 |
|  |  | AT (\*) *StartTagContent* | 0.1 |
|  |  | NS *StartTagContent* | 0.2 |
|  |  | SC *Fragment* | 0.3 |
|  |  | ***ChildContentItems*** **(0.4)** |  |
|  | | | |
|  | *ElementContent* : | | |
|  |  | EE | 0 |
|  |  | *ChildContentItems* (1.0) |  |
|  | | | |
|  | *ChildContentItems (n.m)* : | | |
|  |  | SE (\*) *ElementContent* | *n*. *m* |
|  |  | CH *ElementContent* | *n*.(*m*+1) |
|  |  | ER *ElementContent* | *n*.(*m*+2) |
|  |  | CM *ElementContent* | *n*.(*m*+3).0 |
|  |  | PI *ElementContent* | *n*.(*m*+3).1 |

| Note: |
| --- |
|  |
| * When the value of the [selfContained option](#key-selfContained) is false,   the production with the terminal symbol SC on the right-hand side is absent from the above grammar, and   the use of the non-terminal macro *ChildContentItems* that has *StartTagContent* non-terminal on the left-hand side (shown in bold above) gets expanded with variable values (0.3) instead of (0.4) used above. |
| * When a xsi:type attribute appears in an element where the [built-in element grammar](#key-builtin-elem-grammar) is in effect, it MUST occur before any other AT events of the same element   unless it is known that xsi:type attribute will not impact grammar selection. |
| * When a xsi:nil attribute appears in an element where the [built-in element grammar](#key-builtin-elem-grammar) is in effect, it does not impact grammar selection and is not strictly required to occur before other AT events of the same element. |

| Semantics: | |
| --- | --- |
|  |  |
|  | All productions in the [built-in element grammar](#key-builtin-elem-grammar) of the form *LeftHandSide*: AT (\*) *RightHandSide* are evaluated as follows:   1. Let    *qname* be the [qname](#key-qname) of the attribute matched by AT (\*) 2. If *qname* is not xsi:type or if a production of the form *LeftHandSide* : AT (*xsi:type*) with an [event code](#key-eventcode) of length 1 does not exist in the current element grammar,    create a production of the form    *LeftHandSide* : AT (*qname*) *RightHandSide*    with an [event code](#key-eventcode) 0 and increment the first part of the event code of each production in the current grammar with the non-terminal *LeftHandSide* on the left-hand side. Add this production to the grammar. 3. If *qname* is xsi:type, let *target-type* be the value of the xsi:type attribute and assign it the QName datatype representation (see [**7.1.7 QName**](#encodingQName)). If there is no namespace in scope for the specified qname prefix, set the *uri* of *target-type* to empty ("") and the *localName* to the full lexical value of the QName, including the prefix. Encode *target-type* according to section [**7. Representing Event Content**](#encodingValues). If a grammar can be found for the *target-type* type using the encoded *target-type* representation, evaluate the element contents using the grammar for *target-type* type instead of *RightHandSide*.   The production of the form *LeftHandSide* : AT (*xsi:type*) *RightHandSide* that was previously added to the grammar upon the first occurrence of the xsi:type attribute is evaluated as follows when it is matched:   1. Let *target-type* be the value of the xsi:type attribute and assign it the QName datatype representation (see [**7.1.7 QName**](#encodingQName)). 2. If there is no namespace in scope for the specified [qname](#key-qname) prefix, set the *uri* of *target-type* to empty ("") and the *localName* to the full lexical value of the QName, including the prefix. 3. Represent the value of *target-type* according to section [**7. Representing Event Content**](#encodingValues). 4. If a grammar can be found for the *target-type* type using the encoded *target-type* representation,    evaluate the element contents using the grammar for *target-type* type instead of *RightHandSide*.   All productions of the form *LeftHandSide* : SC *Fragment* are evaluated as follows:   1. Save the string table, grammars and any implementation-specific state learned while processing this EXI Body. 2. Initialize the string table, grammars and any implementation-specific state learned while processing this EXI Body to the state they held just prior to processing this EXI Body. 3. Skip to the next byte-aligned boundary in the stream    if it is not already at such a boundary. 4. Let *qname* be the [qname](#key-qname) of the SE event immediately preceding this SC event. 5. Let *content* be the sequence of events following this SC event that match the grammar for element *qname*, up to and including the terminating EE event. 6. Evaluate the sequence of events (SD, SE(*qname*), *content*, ED) according to the *Fragment* grammar (see [**8.4.2 Built-in Fragment Grammar**](#builtinFragGrammars)). 7. Skip to the next byte-aligned boundary in the stream    if it is not already at such a boundary. 8. Restore the string table, grammars and implementation-specific state learned while processing this EXI Body to that saved in step 1 above.   All productions in the [built-in element grammar](#key-builtin-elem-grammar) of the form *LeftHandSide* : SE (\*) *RightHandSide* are evaluated as follows:   1. Let *qname* be the [qname](#key-qname) of the element matched by SE (\*) 2. If a [global element grammar](#key-global-element-grammar) does not exist for element *qname*, create one according to section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars). 3. Create a production of the form *LeftHandSide* : SE (*qname*) *RightHandSide* with an [event code](#key-eventcode) 0 4. Increment the first part of the [event code](#key-eventcode) of each production in the current grammar with the non-terminal *LeftHandSide* on the left-hand side 5. Add the production created in step    3    to the grammar 6. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname*. 7. Evaluate the remainder of event sequence using *RightHandSide*.   All productions of the form *LeftHandSide* : SE (*qname*) *RightHandSide* that were previously added to the grammar upon the first occurrence of the element that has the [qname](#key-qname) *qname* are evaluated as follows when they are matched:   1. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname* 2. Evaluate the remainder of event sequence using *RightHandSide*.   All productions in the [built-in element grammar](#key-builtin-elem-grammar) of the form *LeftHandSide* : CH *RightHandSide* are evaluated as follows:   1. If a production of the form,    *LeftHandSide* : CH    *RightHandSide* with an [event code](#key-eventcode) of length 1 does not exist in the current element grammar, create one with event code 0 and increment the first part of the event code of each production in the current grammar with the non-terminal    *LeftHandSide* on the left-hand side. 2. Add the production created in step 1 to the grammar 3. Evaluate the remainder of event sequence using *RightHandSide*.   All productions in the [built-in element grammar](#key-builtin-elem-grammar) of the form *LeftHandSide* : EE are evaluated as follows:   1. If a production of the form,    *LeftHandSide* : EE    with an [event code](#key-eventcode) of length 1 does not exist in the current element grammar, create one with event code 0 and increment the first part of the event code of each production in the current grammar with the non-terminal    *LeftHandSide* on the left-hand side. 2. Add the production created in step 1 to the grammar |

### 8.5 Schema-informed Grammars

This section describes the schema-informed grammars used by EXI when schema information is available to describe the contents of the [EXI stream](#key-existream).
Schema information used for processing an EXI stream is either indicated by the header option [schemaId](#key-schemaIdOption), or communicated out-of-band in the absence of [schemaId](#key-schemaIdOption).

Schema-informed grammars accept all XML documents and fragments regardless of whether and how closely they match the schema. The [EXI stream encoder](#key-exiencoder) encodes individual events using schema-informed grammars where they are available and falls back to the built-in XML grammars where they are not. In general, events for which a schema-informed grammar exists will be encoded more efficiently.

Unlike built-in XML grammars, schema-informed grammars are static and do not evolve, which permits the reuse of schema-informed grammars across the processing of multiple EXI streams. This is a single outstanding difference between the two grammar systems.

It is important to note that schema-informed and built-in grammars are often used together within the context of a single [EXI stream](#key-existream). While processing a schema-informed grammar, built-in grammars may be created to represent schema deviations or elements that match wildcards declared in the schema. Even though these built-in grammars occur in the context of a schema-informed stream, they are still dynamic and evolve to represent content learned while processing the EXI stream as is described in [**8.4 Built-in XML Grammars**](#builtinGrammars).

#### 8.5.1 Schema-informed Document Grammar

When schema information is available to describe the contents of an [EXI stream](#key-existream), the following grammar describes the events that will occur in an [EXI document](#key-exidocument).

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  | | | |
|  | *Document* : | | |
|  |  | SD *DocContent* | 0 |
|  | | | |
|  | *DocContent* : | | |
|  |  | SE (G 0) *DocEnd* | 0 |
|  |  | SE (G 1) *DocEnd* | 1 |
|  |  | ⋮ | ⋮ |
|  |  | SE (G *n*−1) *DocEnd* | *n*−1 |
|  |  | SE (\*) *DocEnd* | *n* |
|  |  | DT *DocContent* | (*n*+1).0 |
|  |  | CM *DocContent* | (*n*+1).1.0 |
|  |  | PI *DocContent* | (*n*+1).1.1 |
|  | | | |
|  | | Note: | | | --- | --- | | | |
|  | * The variable   *n* in the grammar above is the number of global elements declared in the schema.   G 0, G 1, ... G *n*−1 represent all the [qnames](#key-qname) of global elements sorted lexicographically, first by local-name, then by uri. | | |
|  | *DocEnd* : | | |
|  |  | ED | 0 |
|  |  | CM *DocEnd* | 1.0 |
|  |  | PI *DocEnd* | 1.1 |

| Semantics: | |
| --- | --- |
|  |  |
|  | In a schema-informed grammar, all productions of the form *LeftHandSide* : SE (\*) *RightHandSide* are evaluated as follows:   1. Let *qname* be the [qname](#key-qname) of the element matched by SE (\*) 2. If a [global element grammar](#key-global-element-grammar) does not exist for element *qname*, create one according to section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars). 3. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname*. 4. Evaluate the remainder of event sequence using *RightHandSide* |

#### 8.5.2 Schema-informed Fragment Grammar

When schema information is available to describe the contents of an [EXI stream](#key-existream), the following grammar describes the events that will occur in an [EXI fragment](#key-exifragment).

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  | | | |
|  | *Fragment* : | | |
|  |  | SD *FragmentContent* | 0 |
|  | | | |
|  | *FragmentContent* : | | |
|  |  | SE (F 0) *FragmentContent* | 0 |
|  |  | SE (F 1) *FragmentContent* | 1 |
|  |  | ⋮ | ⋮ |
|  |  | SE (F *n*−1) *FragmentContent* | *n*−1 |
|  |  | SE (\*) *FragmentContent* | *n* |
|  |  | ED | *n*+1 |
|  |  | CM *FragmentContent* | (*n*+2).0 |
|  |  | PI *FragmentContent* | (*n*+2).1 |
|  | | | |
|  | | Note: | | | --- | --- | | | |
|  | * The variable *n* in the grammar above represents the number of unique element [qnames](#key-qname) declared in the schema. The variables F 0, F 1, ... F n−1 represent these [qnames](#key-qname) sorted lexicographically, first by local-name, then by uri. If there is more than one element declared with the same [qname](#key-qname), the [qname](#key-qname) is included only once.   If all such elements have the same schema type name and {nillable} property value, their content is evaluated according to the specific grammar for that element declaration.   Otherwise, their content is evaluated according to the relaxed Element Fragment grammar described in [**8.5.3 Schema-informed Element Fragment Grammar**](#informedElementFragGrammar). | | |

| Semantics: | |
| --- | --- |
|  |  |
|  | In a schema-informed grammar, all productions of the form *LeftHandSide* : SE (\*) *RightHandSide* are evaluated as follows:   1. Let    *qname* be the [qname](#key-qname) of the element matched by SE (\*) 2. If a [global element grammar](#key-global-element-grammar) does not exist for element *qname*, create one according to section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars). 3. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname*. 4. Evaluate the remainder of event sequence using *RightHandSide* |

#### 8.5.3 Schema-informed Element Fragment Grammar

[Definition:]
When schema information is available to describe the contents of an [EXI stream](#key-existream) and more than one element is declared with the same [qname](#key-qname),
but not all such elements have the same type name and {nillable} property value,
the **Schema-informed Element Fragment Grammar** are used for processing the events that may occur in such elements when they occur inside an EXI fragment or EXI Element Fragment.
The schema-informed element fragment grammar consists of *ElementFragment* and *ElementFragmentTypeEmpty* which are defined below. *ElementFragment* is a grammar that accounts both element declarations and attribute declarations in the schemas, whereas *ElementFragmentTypeEmpty* is a grammar that regards only attribute declarations.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  | | | |
|  | *ElementFragment*0 : | | |
|  |  | AT (A0) [schema-typed value] *ElementFragment*0 | 0 |
|  |  | AT (A1) [schema-typed value] *ElementFragment*0 | 1 |
|  |  | ⋮ | ⋮ |
|  |  | AT (A*n*−1) [schema-typed value] *ElementFragment*0 | *n*−1 |
|  |  | AT (\*) *ElementFragment*0 | *n* |
|  |  | SE (F0) *ElementFragment*2 | *n*+1 |
|  |  | SE (F1) *ElementFragment*2 | *n*+2 |
|  |  | ⋮ | ⋮ |
|  |  | SE (F*m*-1) *ElementFragment*2 | *n*+*m* |
|  |  | SE (\*) *ElementFragment*2 | *n*+*m*+1 |
|  |  | EE | *n*+*m*+2 |
|  |  | CH [untyped value] *ElementFragment*2 | *n*+*m*+3 |
|  | | | |
|  | *ElementFragment*1 : | | |
|  |  | SE (F0) *ElementFragment*2 | *0* |
|  |  | SE (F1) *ElementFragment*2 | 1 |
|  |  | ⋮ | ⋮ |
|  |  | SE (F*m*-1) *ElementFragment*2 | *m*-1 |
|  |  | SE (\*) *ElementFragment*2 | *m* |
|  |  | EE | *m*+1 |
|  |  | CH [untyped value] *ElementFragment*2 | *m*+2 |
|  | | | |
|  | *ElementFragment*2 : | | |
|  |  | SE (F0) *ElementFragment*2 | *0* |
|  |  | SE (F1) *ElementFragment*2 | 1 |
|  |  | ⋮ | ⋮ |
|  |  | SE (F*m*-1) *ElementFragment*2 | *m*-1 |
|  |  | SE (\*) *ElementFragment*2 | *m* |
|  |  | EE | *m*+1 |
|  |  | CH [untyped value] *ElementFragment*2 | *m*+2 |
|  | | | |
|  | *ElementFragmentTypeEmpty*0 : | | |
|  |  | AT (A 0) [schema-typed value] *ElementFragmentTypeEmpty*0 | 0 |
|  |  | AT (A 1) [schema-typed value] *ElementFragmentTypeEmpty*0 | 1 |
|  |  | ⋮ | ⋮ |
|  |  | AT (A *n*−1) [schema-typed value] *ElementFragmentTypeEmpty*0 | *n*−1 |
|  |  | AT (\*) *ElementFragmentTypeEmpty*0 | *n* |
|  |  | EE | *n*+1 |
|  | | | |
|  | *ElementFragmentTypeEmpty*1 : | | |
|  |  | EE | 0 |
|  | | | |
|  | | Note: | | | --- | --- | | | |
|  | * The variable *n* in the grammar above represents   the number of unique [qnames](#key-qname) given to explicitly declared attributes in the schema.   The variables A0 , A1, ... A*n*−1 represent these qnames sorted lexicographically, first by local-name, then by uri. If there is more than one attribute declared with the same [qname](#key-qname), the qname is included only once.   If all such attributes have the same schema type name, their [*value*](#key-valueContentItem) is represented using that type.   Otherwise, their [*value*](#key-valueContentItem) is represented as a String.  * The variable *m* in the grammar above represents the number of unique element [qnames](#key-qname) declared in the schema. The variables F0, F1, ... F*m*-1 represent these qnames sorted lexicographically, first by local-name, then by uri. If there is more than one element declared with the same [qname](#key-qname), the qname is included only once.   If all such elements have the same type name and {nillable} property value, their content is evaluated according to specific grammar for that element declaration.   Otherwise, their content is evaluated according to the relaxed Element Fragment grammar described above. | | |

| Semantics: | |
| --- | --- |
|  |  |
|  | In a schema-informed grammar, all productions of the form *LeftHandSide* : SE (\*) *RightHandSide* are evaluated as follows:   1. Let    *qname* be the [qname](#key-qname) of the element matched by SE (\*) 2. If a [global element grammar](#key-global-element-grammar) does not exist for element *qname*, create one according to section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars). 3. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname*. 4. Evaluate the remainder of event sequence using *RightHandSide*   All productions in the schema-informed element fragment grammar of the form *LeftHandSide*: AT (\*) *RightHandSide* are evaluated as follows:   1. Let    *qname* be the [qname](#key-qname) of the attribute matched by AT (\*) 3. If a global attribute definition exists for *qname*, let *global-type* be the datatype of the global attribute. If the attribute value can be represented using the datatype representation associated with *global-type*, it SHOULD be represented using the datatype representation associated with *global-type* (see [**7. Representing Event Content**](#encodingValues)). If the attribute value is not represented using the datatype representation associated with *global-type*, represent the    attribute event    using the AT (\*) [untyped value] terminal (see [**8.5.4.4 Undeclared Productions**](#undeclaredProductions)).   **Note:** When a schema-informed grammar is in effect, xsi:type and xsi:nil attributes MUST NOT be represented using AT(\*) terminal. |

As with all schema informed element grammars, the schema-informed element fragment grammar is augmented with additional productions that describe events that may occur in an EXI stream, but are not explicitly declared in the schema. The process for augmenting the grammar is described in [**8.5.4.4 Undeclared Productions**](#undeclaredProductions).
For the purposes of this process, the schema-informed element fragment grammar is treated as though it is created from an element declaration with a {nillable} property value of true and a type declaration that has named sub-types, and *ElementFragmentTypeEmpty* is used to serve as the [*TypeEmpty*](#key-type-empty) of the type in the process.

#### 8.5.4 Schema-informed Element and Type Grammars

[Definition:]When one or more XML Schema is available to describe the contents of an EXI stream, a **schema-informed element grammar** *Element*i is derived for each element declaration *E*i described by the schemas, where 0 ≤ *i* < *n* and *n* is the number of element declarations in the schema.

[Definition:]When one or more XML Schema is available to describe the contents of an EXI stream, a **schema-informed type grammar** *Type*i is derived
for each named type declaration *T*i described by the schemas as well as for each of the [built-in primitive types](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#built-in-primitive-datatypes)XS2 and [built-in derived types](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#built-in-derived)XS2, the [complex ur-type](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#key-urType)XS1 and the [simple ur-type](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#dt-anySimpleType)XS2 defined by XML Schema specification [[XML Schema Structures]](#schema1)[[XML Schema Datatypes]](#schema2), where 0 ≤ *i* < *n* and *n* is the total number of such available types.

Each schema-informed element grammar and type grammar is constructed according to the following four steps:

1. Create a proto-grammar that describes the content model according to available schema information (see section [**8.5.4.1 EXI Proto-Grammars**](#protoGrammars)).
2. Normalize the proto-grammar into an EXI grammar (see section [**8.5.4.2 EXI Normalized Grammars**](#normalizedGrammars)).
3. Assign [event codes](#key-eventcode) to each production in the normalized EXI grammar (see section [**8.5.4.3 Event Code Assignment**](#eventCodeAssignment)).
4. Add additional productions to the normalized EXI grammar to represent events that may occur in the EXI stream, but are not described by the schema, such as comments, processing-instructions, schema-deviations, etc. (see section [**8.5.4.4 Undeclared Productions**](#undeclaredProductions)).

Each element grammar *Element*i includes a sequence of *n* non-terminals *Element*i, j, where 0 ≤ *j* < *n*. The content of the entire element is described by the first non-terminal *Element*i, 0. The remaining non-terminals describe portions of the element content. Likewise, each type grammar *Type*i includes a sequence of *n* non-terminals *Type*i, j and the content of the entire type is described by the first non-terminal *Type*i, 0.

The algorithms expressed in this section provide a concise and formal description of the EXI grammars for a given set of XML Schema definitions. More efficient algorithms likely exist for generating these EXI grammars and EXI implementations are free to use any algorithm that produces grammars and [event codes](#key-eventcode) that generate EXI encodings that match those produced by the grammars described here.

An example is provided in the appendix (see [**H Schema-informed Grammar Examples**](#grammarExamples)) that demonstrates the process described in this section to generate a complete schema-informed element grammar from an element declaration
in a schema.

##### 8.5.4.1 EXI Proto-Grammars

This section describes the process for creating the EXI proto-grammars from XML Schema declarations and definitions. EXI proto-grammars differ from normalized EXI grammars in that they may contain productions of the form:

|  |  |  |
| --- | --- | --- |
|  | *LeftHandSide* : | |
|  |  | *RightHandSide* |

where *LeftHandSide* and *RightHandSide* are both non-terminals. Whereas, all productions in a normalized EXI grammar contain exactly one terminal symbol and at most one non-terminal symbol on the right-hand side. This is a restricted form of Greibach normal form [[Greibach Normal Form]](#greibach).

EXI proto-grammars are derived from XML Schema in a straight-forward manner and can easily be normalized with simple algorithm (see [**8.5.4.2 EXI Normalized Grammars**](#normalizedGrammars)).

###### 8.5.4.1.1 Grammar Concatenation Operator

Proto-grammars are specified in a modular, constructive fashion. XML Schema components such as terms, particles, attribute uses are transformed each into a distinct proto-grammar, leveraging proto-grammars of their sub-components. At various stages of proto-grammar construction, two or more of proto-grammars are concatenated one after another to form more composite grammars.

The grammar concatenation operator ⊕ is a binary, associative operator that creates a new grammar from its left and right grammar operands. The new grammar accepts any set of symbols accepted by its left operand followed by any set of symbols accepted by its right operand.

Given a left operand *GrammarL* and a right operand *GrammarR*, the following operation

|  |  |
| --- | --- |
|  | *GrammarL* ⊕ *GrammarR* |

creates a combined grammar by replacing each production of the form

|  |  |  |
| --- | --- | --- |
|  | *GrammarL*k : | |
|  |  | EE |

where 0 ≤ *k* < *n* and *n* is the number of non-terminals that occur on the left-hand side of productions in *GrammarL*, with a production of the form

|  |  |  |
| --- | --- | --- |
|  | *GrammarL*k : | |
|  |  | *GrammarR*0 |

connecting each accept state of *GrammarL* with the start state of *GrammarR*.

###### 8.5.4.1.2 Element Grammars

This section describes the process for creating an EXI element grammar from an XML Schema [element declaration](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#cElement_Declarations)XS1.

Given an element declaration *E*i, with properties {name}, {target namespace}, {type definition}, {scope} and {nillable}, create a corresponding EXI grammar *Element*i for evaluating the contents of elements in the specified {scope} with *qname* local-name = {name} and *qname* uri = {target namespace}
where *qname* is the [qname](#key-qname) of the elements.

Let *T*j be the {type definition} of *E*i and *Type*j be the type grammar created from *T*j. The grammar *Element*i describing the content model of *E*i is created as follows.

| Syntax: |  | |
| --- | --- | --- |
|  | *Element*i , 0 : | |
|  |  | *Type*j , 0 |
|  | | |

###### 8.5.4.1.3 Type Grammars

Given an XML Schema type definition *T*i
with properties {name} and {target namespace},
two type grammars are created, which are denoted by *Type*i and *TypeEmpty*i. [Definition:]***Type***i is a grammar that fully reflects the type definition of *T*i, whereas [Definition:]***TypeEmpty***i is a grammar that
regards
only the attribute uses and attribute wildcards of *T*i, if any.

The grammar *Type*i is used for evaluating the content of elements that are defined to be of type *T*i in the schema.
[Definition:]*Type*i is a **global type grammar** when *T*i is a named type.
*Type*i, when it is a global type grammar, can additionally be used as the effective grammar designated by a xsi:type attribute with the attribute value that is a [qname](#key-qname) with local-name = {name} and uri = {target namespace}.
*TypeEmpty*i is used in place of *Type*i when the element instance that is being evaluated has a xsi:nil attribute with the value *true*.

Sections [**8.5.4.1.3.1 Simple Type Grammars**](#simpleTypeGrammars) and [**8.5.4.1.3.2 Complex Type Grammars**](#complexTypeGrammars) describe the processes for creating *Type*i and *TypeEmpty*i from XML Schema [simple type definitions](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#Simple_Type_Definitions)XS1 and [complex type definitions](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#Complex_Type_Definitions)XS1 defined in schemas as well as [built-in primitive types](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#built-in-primitive-datatypes)XS2, [built-in derived types](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#built-in-derived)XS2, [simple ur-type](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#dt-anySimpleType)XS2 and [complex ur-type](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#d0e9252)XS1 defined by XML Schema specification [[XML Schema Datatypes]](#schema2).

###### 8.5.4.1.3.1 Simple Type Grammars

This section describes the process for creating an EXI type grammar from an XML Schema [simple type definition](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#Simple_Type_Definitions)XS1.

Given a simple type definition *T*i,
create two new EXI grammars [*Type*](#key-type)i and [*TypeEmpty*](#key-type-empty)i
following the procedure described below.

Add the following grammar productions to *Type*i and *TypeEmpty*i :

| Syntax: |  | |
| --- | --- | --- |
|  | *Type*i, 0 : | |
|  |  | CH [schema-typed value] *Type*i, 1 |
|  | *Type*i, 1 : | |
|  |  | EE |
|  | | |
|  | *TypeEmpty*i, 0 : | |
|  |  | EE |
|  | | |

| Note: |
| --- |
|  | Productions of the form *LeftHandSide* : CH [schema-typed value] *RightHandSide* represent typed character data that can be represented using the EXI datatype representation associated with the simple type definition (see [**7. Representing Event Content**](#encodingValues)). Character data that can be represented using the EXI datatype representation associated with the simple type definition SHOULD be represented this way. Character data that is not represented using the EXI datatype representation associated with the simple type definition is represented by productions of the form *LeftHandSide* : CH [untyped value] *RightHandSide* described in section [**8.5.4.4 Undeclared Productions**](#undeclaredProductions). |

###### 8.5.4.1.3.2 Complex Type Grammars

This section describes the process for creating an EXI type grammar from an XML Schema [complex type definition](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#Complex_Type_Definitions)XS1.

Given a complex type definition *T*i, with properties {name}, {target namespace},
{attribute uses}, {attribute wildcard} and {content type},
create two EXI grammars [*Type*](#key-type)i and [*TypeEmpty*](#key-type-empty)i
following the procedure described below.

Generate a grammar *Attribute*i, for each attribute use *A*i in {attribute uses} according to section [**8.5.4.1.4 Attribute Uses**](#attributeUses).

Sort the attribute use grammars first by qname local-name, then by qname uri to form a sequence of grammars *G*0, *G*1, …, *G*n−1, where *n* is the number of attribute uses in {attribute uses}.

If an {attribute wildcard} is specified, increment *n* and generate additional attribute use grammars *G*n−1 as follows:

|  |  |  |
| --- | --- | --- |
|  | *G*n−1, 0 : | |
|  |  | EE |

|  |  |  |
| --- | --- | --- |
|  | *G*n−1, 1 : | |
|  |  | EE |

When the {attribute wildcard}'s {namespace constraint} is *any*, or
a pair of *not* and either a namespace name or the special value
*absent* indicating no namespace,
add the following production to each grammar
*G*i
generated above,
where 0 ≤ *i* < *n* :

|  |  |  |
| --- | --- | --- |
|  | *G*i, 0 : | |
|  |  | AT (\*) *G*i, 0 |

Otherwise, that is, when {namespace constraint} is a set of values whose members are namespace names or the special value *absent* indicating no namespace,
add the following production to each grammar
*G*i
generated above
where 0 ≤ *i* < *n* :

|  |  |  |
| --- | --- | --- |
|  | *G*i, 0 : | |
|  |  | AT(*urix* : \*) *G*i, 0 |
|  | | |
| where *uri**x* is a member value of {namespace constraint}, provided that it is the empty string (i.e. "") that is used as *uri**x* when the member value is the special value *absent*. Each *urix* is used to augment the uri partition of the String table. Section [**7.3.1 String Table Partitions**](#stringTablePartitions) describes how these *uri* strings are put into String table for pre-population. | | |
|  | | |
| If there is neither an attribute use nor an {attribute wildcard}, *G*0 of the following form is used as an attribute use grammar.   |  |  |  | | --- | --- | --- | |  | *G*0, 0 : | | |  |  | EE | | | |
|  | | |
| | Note: | | --- | |  | | When xsi:type and/or xsi:nil attributes appear in an element where schema-informed grammars are in effect, they MUST occur before any other AT events of the same element, with xsi:type placed before xsi:nil when they both occur. | | | |
|  | | |
| | Semantics: | | --- | |  | | In complex type grammars, all productions of the form *LeftHandSide*: AT (\*) *RightHandSide* and *LeftHandSide*: AT(*uri**x* : \*) *RightHandSide* that stem from attribute wildcards are evaluated as follows: |  1. Let    *qname* be the [qname](#key-qname) of the attribute matched by AT (\*) or AT(*uri**x* : \*) 2. If a global attribute definition exists for *qname*, let *global-type* be the datatype of the global attribute. If the attribute value can be represented using the datatype representation associated with *global-type*, it SHOULD be represented using the datatype representation associated with *global-type* (see [**7. Representing Event Content**](#encodingValues)). If the attribute value is not represented using the datatype representation associated with *global-type*, represent the    attribute event    using the AT (\*) [untyped value] terminal (see [**8.5.4.4 Undeclared Productions**](#undeclaredProductions)).   **Note:** When a schema-informed grammar is in effect, xsi:type and xsi:nil attributes MUST NOT be represented using AT(\*) terminal. | | |

The grammar *TypeEmpty*i is created by combining the sequence of attribute use grammars
terminated by an empty {content type} grammar
as follows:

|  |  |
| --- | --- |
|  | *TypeEmpty*i = *G*0 ⊕ *G*1 ⊕ … ⊕ *G*n−1 ⊕ *Content*i |

where the grammar *Content*i is created as follows:

|  |  |  |
| --- | --- | --- |
|  | *Content*i, 0 : | |
|  |  | EE |

The grammar *Type*i is generated as follows.

If {content type} is a simple type definition
*T*j
, generate a grammar *Content*i
as *Type*j
according to section [**8.5.4.1.3.1 Simple Type Grammars**](#simpleTypeGrammars).
If {content type} has a content model particle, generate a grammar *Content*i according to section [**8.5.4.1.5 Particles**](#particles).
Otherwise, if {content type} is *empty*,
create a grammar *Content*i as follows:

|  |  |  |
| --- | --- | --- |
|  | *Content*i : | |
|  |  | EE |

If {content type} is a content model particle with mixed content, add a production for each non-terminal *Content*i , j in *Content*i as follows:

|  |  |  |
| --- | --- | --- |
|  | *Content*i, j : | |
|  |  | CH [untyped value] *Content*i, j |

| Note: | |
| --- | --- |
|  | The value of each Characters event that has an [untyped value] is represented as a String (see [**7.1.10 String**](#encodingString)). |

Then, create a copy *H*i of each attribute use grammar *G*i and create the grammar *Type*i by combining this sequence of attribute use grammars and the *Content*i grammar using the grammar concatenation operator defined in section [**8.5.4.1.1 Grammar Concatenation Operator**](#grammarConcatOperator) as follows:

|  |  |
| --- | --- |
|  | *Type*i = *H*0 ⊕ *H*1 ⊕ … ⊕ *H*n−1 ⊕ *Content*i |

###### 8.5.4.1.4 Attribute Uses

Given an attribute use *A*i with properties {required} and {attribute declaration}, where {attribute declaration} has properties {name}, {target namespace}, {type definition} and {scope}, generate a new EXI grammar *Attribute*i for evaluating attributes in the specified {scope} with *qname* local-name = {name} and *qname* uri = {target namespace}
where *qname* is the [qname](#key-qname) of the attributes.
Add the following grammar productions to *Attribute*i:

|  |  |  |
| --- | --- | --- |
|  | *Attribute*i, 0 : | |
|  |  | AT(*qname*) [schema-typed value] *Attribute*i, 1 |
|  | | |
|  | *Attribute*i, 1 : | |
|  |  | EE |

If the {required} property of *A*i is false, add the following grammar production to indicate this attribute occurrence may be omitted from the content model.

|  |  |  |
| --- | --- | --- |
|  | *Attribute*i, 0 : | |
|  |  | EE |

| Note: |
| --- |
|  | Productions of the form *LeftHandSide* : AT(*qname*) [schema-typed value] *RightHandSide* represent typed attributes that occur in schema-valid contexts with values that can be represented using the EXI datatype representation associated with the attribute's {type definition} (see [**7. Representing Event Content**](#encodingValues)). Attributes that occur in schema-valid contexts that can be represented using the EXI datatype representation associated with the attribute's {type definition}, SHOULD be represented this way. Attributes that are not represented this way, are represented using the alternate forms of AT events described in section [**8.5.4.4 Undeclared Productions**](#undeclaredProductions). |

###### 8.5.4.1.5 Particles

Given
an XML Schema [particle](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#cParticles)XS1
*P*i with {min occurs}, {max occurs} and {term} properties, generate a grammar *Particle*i for evaluating instances of *P*i as follows.

If {term} is an element declaration, generate the grammar *Term*0 according to section [**8.5.4.1.6 Element Terms**](#elementTerms). If {term} is a wildcard, generate the grammar *Term*0 according to section [**8.5.4.1.7 Wildcard Terms**](#wildcardTerms) Wildcard Terms. If {term} is a model group, generate the grammar *Term*0 according to section [**8.5.4.1.8 Model Group Terms**](#modelGroupTerms).

Create {min occurs} copies of *Term*0.

|  |  |
| --- | --- |
|  | *G*0, *G*1, …, *G*{min occurs}-1 |

If {max occurs} is not unbounded, create {max occurs} – {min occurs} additional copies of *Term*0,

|  |  |
| --- | --- |
|  | *G*{min occurs}, *G*{min occurs}+1, …, *G*{max occurs}-1 |

Add the following productions to each of the grammars that do not already have a production of this form.

|  |  |  |
| --- | --- | --- |
|  | *G*i, 0 : | |
|  |  | EE     where {min occurs} ≤ *i* < {max occurs} |

indicating these instances of *Term*0 may be omitted from the content model. Then, create the grammar for *Particle*i using the grammar concatenation operator defined in section [**8.5.4.1.1 Grammar Concatenation Operator**](#grammarConcatOperator) as follows:

|  |  |
| --- | --- |
|  | *Particle*i = *G*0 ⊕ *G*1 ⊕ … ⊕ *G*{max occurs}-1 |

Otherwise, if {max occurs} is unbounded, generate one additional copy of *Term*0, *G*{min occurs} and replace all productions of the form:

|  |  |  |
| --- | --- | --- |
|  | *G*{min occurs}, k : | |
|  |  | EE |

with productions of the form:

|  |  |  |
| --- | --- | --- |
|  | *G*{min occurs}, k : | |
|  |  | *G*{min occurs}, 0 |

indicating this term may be repeated indefinitely. Then, when there is no more production of the form:

|  |  |  |
| --- | --- | --- |
|  | *G*{min occurs}, 0 : | |
|  |  | EE |

add one after the other productions with the non-terminal *G*{min occurs}, 0 on the left-hand side, indicating this term may be omitted from the content model. Then, create the grammar for *Particle*i using the grammar concatenation operator defined in section [**8.5.4.1.1 Grammar Concatenation Operator**](#grammarConcatOperator) as follows:

|  |  |
| --- | --- |
|  | *Particle*i = *G*0 ⊕ *G*1 ⊕ … ⊕ *G*{min occurs} |

###### 8.5.4.1.6 Element Terms

Given a particle {term} *PT*i that is an XML Schema [element declaration](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#cElement_Declarations)XS1
with properties {name},
{substitution group affiliation}
and {target namespace}, let *S* be the set of element declarations that directly or indirectly reaches the element declaration *PT*i through the chain of {substitution group affiliation} property of the elements, plus *PT*i itself if was not in the set. Sort the element declarations in *S* lexicographically first by {name} then by {target namespace}, which makes a sorted list of element declarations *E0*, *E1*, … *En−1* where *n* is the cardinality of *S*. Then create the grammar *ParticleTerm*i with the following grammar productions:

| Syntax: | | |
| --- | --- | --- |
|  | | |
|  | *ParticleTerm*i, 0 : | |
|  |  | SE(*qname*0) *ParticleTerm*i, 1 |
|  |  | SE(*qname*1) *ParticleTerm*i, 1 |
|  |  | ⋮ |
|  |  | SE(*qname*n−1) *ParticleTerm*i, 1 |
|  | | |
|  | *ParticleTerm*i, 1 : | |
|  |  | EE |
|  | | |

| Note: | | |
| --- | --- | --- |
|  |  | |
|  | In the productions above, *qnamex* (where 0 ≤ *x* < n) represents a [qname](#key-qname) of which local-name and uri are {name} property and {target namespace} property of the element declaration *Ex*, respectively. | |
|  | | |

| Semantics: | | |
| --- | --- | --- |
|  |  | |
|  | In a schema-informed grammar, all productions of the form *LeftHandSide* : SE(*qname*) *RightHandSide* are evaluated as follows:  1. Evaluate the element contents using the SE(*qname*) grammar. 2. Evaluate the remainder of the event sequence using *RightHandSide* | |

###### 8.5.4.1.7 Wildcard Terms

Given a particle {term} *PT*i that is an XML Schema [wildcard](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/#Wildcards)XS1
with property {namespace constraint}, a grammar that reflects the wildcard definition is created as follows.

Create a grammar *ParticleTerm*i containing the following grammar production:

|  |  |  |
| --- | --- | --- |
|  | *ParticleTerm*i, 1 : | |
|  |  | EE |

When the wildcard's {namespace constraint} is
*any*, or a pair of *not* and either a namespace name or the special value *absent* indicating no namespace,
add the following production to *ParticleTerm*i.

|  |  |  |
| --- | --- | --- |
|  | *ParticleTerm*i, 0 : | |
|  |  | SE(\*) *ParticleTerm*i, 1 |

Otherwise, that is, when {namespace constraint} is a set of values whose members are namespace names or the special value *absent* indicating no namespace,
add the following production to *ParticleTerm*i:

|  |  |  |
| --- | --- | --- |
|  | *ParticleTerm*i, 0 : | |
|  |  | SE(*urix*: \*) *ParticleTerm*i, 1 |
|  | | |

for each member value *uri**x* in {namespace constraint},
provided that it is the empty string (i.e. "") that is used as *uri**x* when the member value is the special value *absent*.
Each *urix* is used to augment the uri partition of the String table.
Section [**7.3.1 String Table Partitions**](#stringTablePartitions) describes how these *uri* strings are put into String table for pre-population.

| Semantics: | |
| --- | --- |
|  |  |
|  | In a schema-informed grammar, all productions of the form *LeftHandSide* : Terminal *RightHandSide* where Terminal is one of SE (\*) or SE (*urix*: \*) are evaluated as follows:  1. Let *qname* be the [qname](#key-qname) of the element matched by SE (\*)    or SE(*urix*: \*) 2. If a [global element grammar](#key-global-element-grammar) does not exist for element *qname*, create one according to section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars). 3. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname*. 4. Evaluate the remainder of the event sequence using *RightHandSide* |

###### 8.5.4.1.8 Model Group Terms

###### 8.5.4.1.8.1 Sequence Model Groups

Given a particle {term} *PT*i that is a model group with {compositor} equal to "sequence" and a list of *n* {particles} *P*0, *P*1, …, *P*n−1, create a grammar *ParticleTerm*i as follows:

If the value of *n* is 0, add the following productions to the grammar *ParticleTerm*i.

|  |  |  |
| --- | --- | --- |
|  | *ParticleTerm*i, 0 : | |
|  |  | EE |

Otherwise, generate a sequence of grammars *Particle*0, *Particle*1, …, *Particle*n−1 corresponding to the list of particles *P*0, *P*1, …, *P*n−1 according to section [**8.5.4.1.5 Particles**](#particles). Then combine the sequence of grammars using the grammar concatenation operator defined in section [**8.5.4.1.1 Grammar Concatenation Operator**](#grammarConcatOperator) as follows:

|  |  |
| --- | --- |
|  | *ParticleTerm*i = *Particle*0 ⊕ *Particle*1 ⊕ … ⊕ *Particle*n−1 |

###### 8.5.4.1.8.2 Choice Model Groups

Given a particle {term} *PT*i that is a model group with {compositor} equal to "choice" and a list of *n* {particles} *P*0, *P*1, …, *P*n−1, create a grammar *ParticleTerm*i as follows:

If the value of *n* is 0, add the following productions to the grammar *ParticleTerm*i.

|  |  |  |
| --- | --- | --- |
|  | *ParticleTerm*i, 0 : | |
|  |  | EE |

Otherwise, generate a sequence of grammar productions *Particle*0, *Particle*1, …, *Particle*n−1 corresponding to the list of particles *P*0, *P*1, …, *P*n−1 according to section [**8.5.4.1.5 Particles**](#particles). Then create the grammar *ParticleTerm*i with the following grammar productions:

|  |  |  |
| --- | --- | --- |
|  | *ParticleTerm*i, 0 : | |
|  |  | *Particle*0, 0 |
|  |  |  |
|  |  | *Particle*1, 0 |
|  |  | ⋮ |
|  |  | *Particle*n−1, 0 |

indicating the grammar for the term may accept any one of the given {particles}.

###### 8.5.4.1.8.3 All Model Groups

Given a particle {term} *PT*i that is a model group with {compositor} equal to "all" and a list of *n*   { particles } *P*0, *P*1, ..., *P*n−1, create a grammar *ParticleTerm*i as follows:

Add the following production to the grammar *ParticleTerm*i.

|  |  |  |
| --- | --- | --- |
|  | *ParticleTerm*i, 0 : | |
|  |  | EE |

If the value of *n* is not 0, generate a sequence of grammar productions *Particle*0, *Particle*1, …, *Particle*n−1 corresponding to the list of particles *P*0, *P*1, …, *P*n−1 according to section [**8.5.4.1.5 Particles**](#particles).

Replace all productions of the form:

|  |  |  |
| --- | --- | --- |
|  | *Particle*j , k : | |
|  |  | EE |

with productions of the form:

|  |  |  |
| --- | --- | --- |
|  | *Particle*j , k : | |
|  |  | *ParticleTerm*i, 0 |

where 0 ≤ *j* < *n*, and 0 ≤ *k* < *m* with *m* denoting the number non-terminals in the grammar *Particle*j.

Add the following productions to the grammar *ParticleTerm*i.

|  |  |  |
| --- | --- | --- |
|  | *ParticleTerm*i, 0 : | |
|  |  | *Particle*0, 0 |
|  |  |  |
|  |  | *Particle*1, 0 |
|  |  | ⋮ |
|  |  | *Particle*n−1, 0 |

**Note:**

The grammar above can accept any sequence of the given {particles} in any order. This grammar is intentionally simple and succinct, enabling high-performance, low-footprint implementations on a wide range of devices, including those with very limited memory resources. More elaborate and precise grammars for the "all" group are possible; however, the associated improvement in precision is not sufficient to justify their code-footprint and memory resource requirements.

##### 8.5.4.2 EXI Normalized Grammars

This section describes the process for converting an EXI proto-grammar
generated
from an XML Schema in accordance with section [**8.5.4.1 EXI Proto-Grammars**](#protoGrammars) into an EXI normalized grammar. Each production in an EXI normalized grammar has exactly one non-terminal symbol on the left-hand side and one terminal symbol on the right-hand side followed by at most one non-terminal symbol on the right-hand side. In addition, EXI normalized grammars contain no two grammar productions with the same non-terminal on the left-hand side and the same terminal symbol on the right-hand side. This is a restricted form of Greibach normal form [[Greibach Normal Form]](#greibach).

EXI proto-grammars differ from normalized EXI grammars in that they may contain productions of the form:

|  |  |  |
| --- | --- | --- |
|  | *LeftHandSide* : | |
|  |  | *RightHandSide* |

where *LeftHandSide* and *RightHandSide* are both non-terminals. Therefore, the first step of the normalization process focuses on replacing productions in this form with productions that conform to the EXI normalized grammar rules. This process can produce a grammar that has more than one production with the same non-terminal on the left-hand side and the same terminal symbol on the right-hand side. Therefore, the second step focuses on eliminating such productions.

The first step of the normalization process is described in Section [**8.5.4.2.1 Eliminating Productions with no Terminal Symbol**](#eliminatingProductions). The second step is described in section [**8.5.4.2.2 Eliminating Duplicate Terminal Symbols**](#eliminatingSymbols). Once these two steps are completed, the grammar will be an EXI normalized grammar.

###### 8.5.4.2.1 Eliminating Productions with no Terminal Symbol

Given an EXI proto-grammar *G*i, with non-terminals *G*i, 0, *G*i, 1, …, *G*i, n−1, replace each production of the form:

|  |  |  |
| --- | --- | --- |
|  | *G*i, j : | |
|  |  | *G*i, k    where 0 ≤ *j* < *n* and 0 ≤ *k* < *n* |

with a set of productions:

|  |  |  |
| --- | --- | --- |
|  | *G*i, j : | |
|  |  | *RHS*(*G*i, k)0 |
|  |  | *RHS*(*G*i, k)1 |
|  |  | ⋮ |
|  |  | *RHS*(*G*i, k)m-1 |

where *RHS*(*G*i, k)0, *RHS*(*G*i, k)1, …, *RHS*(*G*i, k)m-1 represents the right-hand side of each production in *G*i that has the non-terminal *G*i, k on the left-hand side and *m* is the number of such productions.

Remove such productions if any among *G*i, j : *RHS*(*G*i, k)h where 0 ≤ *h* < *m* of which the right-hand side either is identical to the left-hand side, or has previously been replaced while applying the process described in this section to productions with *G*i, j on the left-hand side.

Repeat this process until there are no more
productions
of the form:

|  |  |  |
| --- | --- | --- |
|  | *G*i, j : | |
|  |  | *G*i, k    where 0 ≤ *j* < *n* and 0 ≤ *k* < *n* |

in the grammar *G*i.

###### 8.5.4.2.2 Eliminating Duplicate Terminal Symbols

Given an EXI proto-grammar *G*i, with non-terminals *G*i, 0, *G*i, 1, …, *G*i, n−1, identify all pairs of productions that have the same non-terminal on the left-hand side and the same terminal symbol on the right-hand side of the form:

|  |  |  |
| --- | --- | --- |
|  | *G*i, j : | |
|  |  | Terminal *G*i, k |
|  |  | Terminal *G*i, l |

where *k*  ≠  *l* and Terminal represents a particular terminal symbol and replace them with a single production:

|  |  |  |
| --- | --- | --- |
|  | *G*i, j : | |
|  |  | Terminal *G*i, k ⊔ l |

where *G*i, k ⊔ l is a distinct non-terminal that accepts the inputs accepted by *G*i, k and the inputs accepted by *G*i, l.
Here the notation "  k ⊔ l  " denotes a union set of integers and is used to uniquely identify the index of such a non-terminal.

If the non-terminal *G*i, k ⊔ l does not exist, create it as follows:

|  |  |  |
| --- | --- | --- |
|  | *G*i, k ⊔ l : | |
|  |  | *RHS*(*G*i, k)0 |
|  |  | *RHS*(*G*i, k)1 |
|  |  | ⋮ |
|  |  | *RHS*(*G*i, k)m-1 |
|  |  |  |
|  |  |  |
|  |  | *RHS*(*G*i, l)0 |
|  |  | *RHS*(*G*i, l)1 |
|  |  | ⋮ |
|  |  | *RHS*(*G*i, l)n−1 |

where *RHS*(*G*i, k)0,
*RHS*(*G*i, k)1,
…,
*RHS*(*G*i, k)m-1
and
*RHS*(*G*i, l)0,
*RHS*(*G*i, l)1,
…,
*RHS*(*G*i, l)n−1
represent the right-hand side of each production in the Grammar *G*i that has the non-terminals *G*j, k and *G*j, l on the left-hand side respectively and *m* and *n* are the number of such productions.

Repeat this process until there are no more productions in the grammar *G*i of the form:

|  |  |  |
| --- | --- | --- |
|  | *G*i, j : | |
|  |  | Terminal *G*i, k |
|  |  | Terminal *G*i, l |

Then, identify any identical productions of the following form:

|  |  |  |
| --- | --- | --- |
|  | *G*i, j : | |
|  |  | Terminal *G*i, k |
|  |  | Terminal *G*i, k |

where 0 ≤ *k* < *n*, *n* is the number of productions in *G*i and Terminal represents a specific terminal symbol, then remove one of them until there are no more productions remaining in the grammar *G*i of this form.

##### 8.5.4.3 Event Code Assignment

This section describes the process for assigning unique [event codes](#key-eventcode) to each production in a normalized EXI grammar. Given a normalized EXI grammar *G*i, apply the following process to each unique non-terminal *G*i, j that occurs on the left-hand side of the productions in *G*i where 0 ≤ *j* < *n* and *n* is the number of such non-terminals in *G*i.

Sort all productions with *G*i, j on the left-hand side in the following order:

1. all productions with AT(*qname*) on the right-hand side
   sorted lexicographically by *qname* local-name, then by *qname* uri, followed by
2. all productions with AT(*urix* : \*) on the right-hand side sorted lexicographically by *uri*, followed by
3. any production with AT (\*) on the right-hand side, followed by
4. all productions with SE(*qname*) on the right-hand side sorted in schema order, followed by
5. all productions with SE(*urix* : \*) on the right-hand side sorted in schema order, followed by
6. any production with SE(\*) on the right-hand side, followed by
7. any production with EE on the right-hand side, followed by
8. any production with CH on the right-hand side.

In step 4 and step 5, the schema order of productions with SE(*qname*) and SE(*urix* : \*) on the right-hand side is determined by the order of the corresponding particles in the schema after any references to named model groups in the schema are expanded in place with the group definitions themselves. A content model of a complex type can be seen as a tree that consists of particles where particles of either element declaration terms or wildcard terms appear as leaves, and the order is assigned to those leaf particles by traversing the tree by depth-first method.

Given the sorted list of productions *P*0, *P*1, … *P*n with the non-terminal *G*i, j on the left-hand side, assign [event codes](#key-eventcode) to each of the productions as follows:

| Productions | | Event Code |
| --- | --- | --- |
|  |  |  |
|  | *P*0 | 0 |
|  | *P*1 | 1 |
|  | ⋮ | ⋮ |
|  | *P*n−1 | *n*−1 |

##### 8.5.4.4 Undeclared Productions

The normalized element and type grammars
generated
from a schema describe the sequences of child elements, attributes and character events that may occur in a particular EXI stream. However, there are additional events that may occur in an EXI stream that are not described by the schema, for example events representing comments, processing-instructions, schema deviations, etc.

This section first describes the process for, in cases with [strict option](#key-strictOption) value set to false, augmenting the normalized element and type grammars with productions that describe events that may occur in the EXI stream, but are not explicitly declared in the schema. It then describes the way, in cases with [strict option](#key-strictOption) value set to true, normalized element and type grammars are supplemented with productions to be prepared for the occurrences of xsi:type and xsi:nil attributes that are permitted by the schema.

In the normalized grammars, terminal symbols AT and CH represent attribute and character events that can be represented by the EXI datatype representations associated with their schema datatypes (see [**7. Representing Event Content**](#encodingValues)).
When the [strict option](#key-strictOption) is false, additional untyped AT and CH terminal symbols are added that can be used for representing attributes and character events that cannot be represented by the associated EXI datatype representations (e.g., schema-invalid values). The following table shows the notation used for such AT and CH terminals along with their definitions.

| Notation | Definition |
| --- | --- |
| AT (*qname*) [untyped value] | Terminal symbol that matches an attribute event with [qname](#key-qname) *qname* and an untyped value. |
| AT (\*) [untyped value] | Terminal symbol that matches an attribute event with any [qname](#key-qname) and an untyped value. |
| CH [untyped value] | Terminal symbol that matches a characters event with an untyped value. |

###### 8.5.4.4.1 Adding Productions when Strict is False

This section describes the process for augmenting the normalized grammars when the value of the [strict option](#key-strictOption) is false.

[Definition:]For each normalized element grammar *Element*i,
an unique index number ***content*** is determined such that: for each set of grammar productions with left-hand side non-terminal symbol of index smaller than *content* there is at least one production with AT terminal symbol and the rest of the productions in *Element*i with left-hand side non-terminal symbols of indices equal or greater than *content* do not have AT terminal symbols. The left-hand side non-terminal symbols indices are assigned in ascending order with the entry non-terminal symbol of *Element*i being assigned index 0 (zero). If there are no productions in *Element*i that have AT terminal symbols on their right-hand side, the content index is 0.

For each normalized element grammar *Element*i, create a copy *Element*i, content2 of *Element*i, content where the index "content" is the [*content*](#key-contentIndex) of the
*Element*i grammar. Then, apply the following procedures.

Add the following production to each non-terminal *Element*i, j that does not already include a production of the form *Element*i, j : EE, such that 0 ≤ j ≤ content.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, j : | | |
|  |  | EE | *n*.*m* |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |
|  | | | |

Let *E*i be the element declaration from which *Element*i was created and *T*k be the {type definition} of *E*i. Let
[*Type*k](#key-type)
and
[*TypeEmpty*k](#key-type-empty)
be the type grammars created from *T*k (see section [**8.5.4.1.3 Type Grammars**](#typeGrammars)). Add the following productions to *Element*i.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, 0 : | | |
|  |  | AT(xsi:type) *Element*i, 0 | *n*.*m* |
|  |  | AT(xsi:nil) *Element*i, 0 | *n*.(*m*+1) |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |
|  | | | |

| Note: | |
| --- | --- |
|  |  |
|  | When xsi:type and/or xsi:nil attributes appear in an element where schema-informed grammars are in effect, they MUST occur before any other attribute events of the same element, with xsi:type placed before xsi:nil when they both occur. |
|  |

| Semantics: | |
| --- | --- |
|  |  |
|  | All productions of the form *LeftHandSide* : AT (xsi:type) *RightHandSide* are evaluated as follows:  1. Let *target-type* be the value of the xsi:type attribute and assign it the QName datatype representation (see [**7.1.7 QName**](#encodingQName)). 2. If there is no namespace in scope for the specified [qname](#key-qname) prefix, set the *uri* of *target-type* to empty ("") and the *localName* to the full lexical value of the QName, including the prefix. 3. Represent the value of *target-type* according to section [**7. Representing Event Content**](#encodingValues). 4. If a grammar can be found for the *target-type* type using the encoded *target-type* representation,    evaluate the element contents using the grammar for *target-type* type instead of *RightHandSide*. |
|  | In a schema-informed grammar, all productions of the form *LeftHandSide* : AT (xsi:nil) *RightHandSide* are evaluated as follows:  1. Let *nil* be the value of the xsi:nil attribute. 2. If *nil* is a valid Boolean, assign it the Boolean datatype representation (see [**7.1.2 Boolean**](#encodingBoolean)) and encode it according to section [**7. Representing Event Content**](#encodingValues). If *nil* is not a valid Boolean, represent the    xsi:nil attribute    event using the AT (\*) [untyped value] terminal (see [**8.5.4.4 Undeclared Productions**](#undeclaredProductions)). 3. If the value of *nil* is true, evaluate the element contents using the grammar    *TypeEmpty*k    defined above rather than *RightHandSide*. |

For each non-terminal *Element*i, j, such that 0 ≤ j ≤ content , with zero or more productions of the following form:

|  |  |  |
| --- | --- | --- |
|  | *Element*i, j : | |
|  |  | AT (*qname*0) [schema-typed value] *NonTerminal*0 |
|  |  | AT (*qname*1) [schema-typed value] *NonTerminal*1 |
|  |  | ⋮ |
|  |  | AT (*qname**x*-1) [schema-typed value] *NonTerminal*x-1 |

where *x* represents the number of attributes declared in the schema for this context, add the following productions:

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, j : | | |
|  |  | AT (\*) *Element*i, j | *n*.*m* |
|  |  | AT (*qname*0) [untyped value] *NonTerminal*0 | *n*.(*m*+1).0 |
|  |  | AT (*qname*1) [untyped value] *NonTerminal*1 | *n*.(*m*+1).1 |
|  |  | ⋮ | ⋮ |
|  |  | AT (*qname**x*-1) [untyped value] *NonTerminal*x-1 | *n*.(*m*+1).(*x*-1) |
|  |  | AT (\*) [untyped value] *Element*i, j | *n*.(*m*+1).(*x*) |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |
|  | | | |

| Note: |
| --- |
|  |
| * The value of each   attribute   event that has an [untyped value] is represented as a String (see [**7.1.10 String**](#encodingString)). |
| * Like an element, an attribute may occur in a schema-invalid context, have a untyped (e.g., schema-invalid) value or both. However, unlike an element whose occurrence and value are represented by separate SE and CH events, the occurrence and value of an attribute are represented by a single AT event. Consequently, four kinds of AT   terminal symbols   are needed for the four possible representations of an attribute event   in schema-informed grammars.   The table below shows these four kinds of AT terminal symbols   along with the equivalent combinations of SE and CH   terminal symbols   for representing elements.      Table 8-1.   Equivalent terminal symbols   for different attribute and element representations    |  | Schema-typed value | Untyped value |   | --- | --- | --- |   | Schema-valid occurrence | |  | | --- | | AT (*qname*) [schema-typed value] | | SE (*qname*) CH [schema-typed value] | | |  | | --- | | AT (*qname*) [untyped value] | | SE (*qname*) CH [untyped value] | |   | Schema-invalid occurrence | |  | | --- | | AT (\*) | | SE (\*) CH [schema-typed value] | | |  | | --- | | AT (\*) [untyped value] | | SE (\*) CH [untyped value] | |     Note that an attribute matching AT (\*) terminal without [untyped value] predication   in schema-informed grammars bears an untyped value unless there is a global attribute   definition available for *qname* where *qname* is the   [qname](#key-qname) of the attribute.   When a global attribute definition is available for *qname*, the attribute   value is represented according to the datatype of the global attribute.  In the above table, AT (\*) terminal without [untyped value] predication is shown   only in the bottom left cell for simplicity. To be more precise, it might well extend into the   bottom right cell because attributes matching the terminal bear schema-typed values in   some cases or untyped values in others depending on the availability of a global   attribute definition that denotes the attribute. |
| * When xsi:type and/or xsi:nil attributes appear in an element where schema-informed grammars are in effect, they MUST occur before any other   attribute   events of the same element, with xsi:type placed before xsi:nil when they both occur. |

| Semantics: | |
| --- | --- |
|  |  |
|  | In a schema-informed grammar, all productions of the form *LeftHandSide* : AT (\*) are evaluated as follows:  1. Let *qname* be the [qname](#key-qname) of the attribute matched by AT (\*) 2. If a global attribute definition exists for *qname*, let *global-type* be the datatype of the global attribute. If the attribute value can be represented using the datatype representation associated with *global-type*, it SHOULD be represented using the datatype representation associated with *global-type* (see [**7. Representing Event Content**](#encodingValues)). If the attribute value is not represented using the datatype representation associated with *global-type*, represent the    attribute event    using the AT (\*) [untyped value] terminal (see [**8.5.4.4 Undeclared Productions**](#undeclaredProductions)). |
| **Note:** When a schema-informed grammar is in effect, xsi:type and xsi:nil attributes MUST NOT be represented using AT(\*) terminal. AT(\*) [untyped value] terminal, on the other hand, can be used to represent an xsi:nil attribute when there is a production of the form *LeftHandSide* : AT (xsi:nil) where *LeftHandSide* is the left-hand side non-terminal of the AT(\*) [untyped value] terminal in question, and the value of the xsi:nil attribute is unable to be represented using AT (xsi:nil) terminal. AT(\*) [untyped value] terminal MUST NOT be used to represent xsi:type attributes. | |

Add the following production to *Element*i.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, 0 : | | |
|  |  | NS *Element*i, 0 | *n*.*m* |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |
|  | | | |

When the value of the [selfContained option](#key-selfContained) is true, add the following production to *Element*i.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, 0 : | | |
|  |  | SC *Fragment* | *n*.*m* |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |

| Semantics: | |
| --- | --- |
|  |  |
|  | All productions of the form *LeftHandSide* : SC *Fragment* are evaluated as follows:  1. Save the string table, grammars and any implementation-specific state learned while processing this EXI Body. 2. Initialize the string table, grammars and any implementation-specific state learned while processing this EXI Body to the state they held just prior to processing this EXI Body. 3. Skip to the next byte-aligned boundary in the stream    if it is not already at such a boundary. 4. Let *qname* be the [qname](#key-qname) of the SE event immediately preceding this SC event. 5. Let *content* be the sequence of events following this SC event that match the grammar for element *qname*, up to and including the terminating EE event. 6. Evaluate the sequence of events (SD, SE(*qname*), *content*, ED) according to the *Fragment* grammar. (see [**8.5.2 Schema-informed Fragment Grammar**](#informedFragGrammars)) 7. Skip to the next byte-aligned boundary in the stream    if it is not already at such a boundary. 8. Restore the string table, grammars and implementation-specific state learned while processing this EXI Body to that saved in step 1 above. |

Add the following productions to each non-terminal *Element*i, j, such that 0 ≤ j ≤ content .

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, j : | | |
|  |  | SE (\*) *Element*i, content2 | *n*.*m* |
|  |  | CH [untyped value] *Element*i, content2 | *n*.(*m*+1) |
|  |  | ER *Element*i, content2 | *n*.(*m*+2) |
|  |  | CM *Element*i, content2 | *n*.(*m*+3).0 |
|  |  | PI *Element*i, content2 | *n*.(*m*+3).1 |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |
|  | | | |

| Note: |
| --- |
|  |
| * Productions of the form *LeftHandSide* : CH [untyped value] *RightHandSide* match untyped character data represented as a String in the EXI stream (e.g., schema-invalid values). Character data represented using the datatype representation associated with the schema datatype of the character data are matched by productions of the form *LeftHandSide* : CH [schema-typed value] *RightHandSide* described in section [**8.5.4.1.3.1 Simple Type Grammars**](#simpleTypeGrammars). |

| Semantics: | |
| --- | --- |
|  |  |
|  | In a schema-informed grammar, all productions of the form *LeftHandSide* : SE (\*) *RightHandSide* are evaluated as follows:  1. Let *qname* be the [qname](#key-qname) of the element matched by SE (\*) 2. If a [global element grammar](#key-global-element-grammar) does not exist for element *qname*, create one according to section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars). 3. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname*. 4. Evaluate the remainder of the event sequence using *RightHandSide* |

Add the following production to *Element*i, content2 and to each non-terminal *Element*i, j that does not already include a production of the form *Element*i, j : EE, such that content < *j* < *n*, where *n* is the number of non-terminals in *Element*i.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, j : | | |
|  |  | EE | *n*.*m* |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |
|  | | | |

Add the following productions to *Element*i, content2 and to each non-terminal *Element*i, j, such that content < *j* < *n*, where *n* is the number of non-terminals in *Element*i.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, j : | | |
|  |  | SE (\*) *Element*i, j | *n*.*m* |
|  |  | CH [untyped value] *Element*i, j | *n*.(*m*+1) |
|  |  | ER *Element*i, j | *n*.(*m*+2) |
|  |  | CM *Element*i, j | *n*.(*m*+3).0 |
|  |  | PI *Element*i, j | *n*.(*m*+3).1 |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |
|  | | | |

| Semantics: | |
| --- | --- |
|  |  |
|  | In a schema-informed grammar, all productions of the form *LeftHandSide* : SE (\*) *RightHandSide* are evaluated as follows:  1. Let *qname* be the [qname](#key-qname) of the element matched by SE (\*) 2. If a [global element grammar](#key-global-element-grammar) does not exist for element *qname*, create one according to section [**8.4.3 Built-in Element Grammar**](#builtinElemGrammars). 3. Evaluate the element content using the [global element grammar](#key-global-element-grammar) for element *qname*. 4. Evaluate the remainder of the event sequence using *RightHandSide* |

Apply the process described above for element grammars to each normalized type grammar
[*Type*i](#key-type) and
[*TypeEmpty*i](#key-type-empty).

###### 8.5.4.4.2 Adding Productions when Strict is True

This section describes the process for augmenting the normalized grammars when the value of the [strict option](#key-strictOption) is true. For each normalized element grammar *Element*i, apply the following procedures.

Let *E*i be the element declaration from which *Element*i was created and *T*k be the {type definition} of *E*i. If *T*k
either has named sub-types or is a simple type definition of which {variety} is *union*,
add the following production to *Element*i.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, 0 : | | |
|  |  | AT(xsi:type) *Element*i, 0 | *n*.*m* |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |
|  | | | |

| Semantics: | |
| --- | --- |
|  | |
| All productions of the form *LeftHandSide* : AT (xsi:type) *RightHandSide* are evaluated as follows: | |
|  |  |
|  | 1. Let *target-type* be the value of the xsi:type attribute and assign it the QName datatype representation (see [**7.1.7 QName**](#encodingQName)). 2. If there is no namespace in scope for the specified [qname](#key-qname) prefix, set the *uri* of *target-type* to empty ("") and the *localName* to the full lexical value of the QName, including the prefix. 3. Represent the value of *target-type* according to section [**7. Representing Event Content**](#encodingValues). 4. If a grammar can be found for the *target-type* type using the encoded *target-type* representation,    evaluate the element contents using the grammar for *target-type* type instead of *RightHandSide*. |

Let
[*Type*k](#key-type)
and
[*TypeEmpty*k](#key-type-empty)
be the type grammars created from *T*k (see section [**8.5.4.1.3 Type Grammars**](#typeGrammars)). If the {nillable} property of *E*i is true, add the following production to *Element*i.

| Syntax | | | Event Code |
| --- | --- | --- | --- |
|  |  |  |  |
|  | *Element*i, 0 : | | |
|  |  | AT(xsi:nil) *Element*i, 0 | *n*.*m* |
|  | | | |
|  | where *n*.*m* represents the next available [event code](#key-eventcode) with length 2. | | |
|  | | | |

| Semantics: | |
| --- | --- |
|  | |
| In a schema-informed grammar, all productions of the form *LeftHandSide* : AT (xsi:nil) *RightHandSide* are evaluated as follows: | |
|  |  |
|  | 1. Let *nil* be the value of the xsi:nil attribute. 2. If *nil* is a valid Boolean, assign it the Boolean datatype representation (see    [**7.1.2 Boolean**](#encodingBoolean)) and encode it according to section [**7. Representing Event Content**](#encodingValues). Otherwise, the value of the *nil* is schema-invalid and cannot be represented when the value of the [strict option](#key-strictOption) is true. 3. If the value of *nil* is true, evaluate the element contents using the grammar    *TypeEmpty*k    defined above rather than *RightHandSide*. |

| Note: | |
| --- | --- |
|  | |
| * When xsi:type or xsi:nil attributes appear in an element where schema-informed grammars are in effect with [strict option](#key-strictOption) value *true*, they MUST occur before any other attribute events of the same element. | |
| * There are several restrictions peculiar to schema-informed element and type grammars created with [strict option](#key-strictOption) value *true* in the ability to represent a small number of uncommon element information item formulations yet valid to the schemas. This is a consequence of intentional grammar simplification aimed to make the grammars compact enough for and the amount of footprint necessary to process the grammars amenable even to extremely resource-deprived devices. Itemized below are such restrictions. Those restrictions need to be given heed to in the process of making a decision to choose the right [strict option](#key-strictOption) value that works best for each use case. | |
|  | * It is not possible to use xsi:type and xsi:nil attributes together on the same element.   This is due to the fact that xsi:type specifies a target type definition, but xsi:nil is only permitted on nillable elements, not type definitions. |
|  | * It is not possible to use xsi:type for explicitly denoting the natural type (i.e. the type immediately given to an element definition in the schema) of the element unless such a type has named sub-types or is a simple type definition of which {variety} is *union*. |
|  | * Namespace declarations are not available instream. A consequence of this is that instream namespace declarations otherwise available when [strict option](#key-strictOption) value is *false* cannot be turned to for helping decompose qualified names [[Namespaces in XML 1.0]](#XMLNS10)   [[Namespaces in XML 1.1]](#XMLNS11) in AT or CH values into pairs of uri and local-name, including xsi:type attribute values encoded with the [Preserve.lexicalValues](#key-preserveLexicalValuesOption) option value *true* wherein the qualified names are represented using String datatype representation (see [**7.1.10 String**](#encodingString)) instead of QName datatype representation (see [**7.1.7 QName**](#encodingQName)). |
|  | * The attributes xsi:schemaLocation and xsi:noNamespaceSchemaLocation can appear only when they match specific schema declarations (i.e., wildcards or ur-types). |

## 9. EXI Compression

The use of EXI compression increases compactness utilizing additional computational resources. EXI compression combines knowledge of XML with a widely adopted, standard compression algorithm to achieve higher compression ratios than would be achievable by applying compression to the entire stream.

EXI compression is applied when [compression](#key-compressionOption) is turned on or when [alignment](#key-alignmentOption)  is set to [pre-compression](#key-precompression). Byte-aligned representations of [event codes](#key-eventcode) and [content items](#key-content-item) are more amenable to compression algorithms compared to unaligned representations because most compression algorithms operate on series of bytes to identify redundancies in the octets. Therefore, when EXI compression is used, [event codes](#key-eventcode) and [content items](#key-content-item) of EXI events are encoded as aligned bytes in accordance with [**6.2 Representing Event Codes**](#encodingEventCodes) and [**7. Representing Event Content**](#encodingValues).

EXI compression splits a sequence of EXI events into a number of contiguous blocks of events.
Events that belong to the same block are transformed into lower entropy groups of similar values called *channels*, which are individually well suited for standard compression algorithms. To reduce compression overhead, smaller channels are combined before compressing them, while larger channels are compressed independently. The criteria EXI compression uses to define and combine channels is intentionally simple to facilitate implementation, reduce processing overhead, and avoid the need to encode channel ordering or grouping information in the format. The figure below presents a schematic view of the steps involved in EXI compression.

![EXI Compression Overview](compression.png)

*Figure 9-1. EXI Compression Overview*

In the following sections, [**9.1 Blocks**](#blocks) defines blocks and explains how EXI events are partitioned into blocks.
Section [**9.2 Channels**](#channels) defines channels, their organization as well as how a group of channels correlate to its corresponding block of events.
Section [**9.3 Compressed Streams**](#CompressedStreams) describes how some channels are combined as needed in preparation for applying compression algorithms on channels.

### 9.1 Blocks

EXI compression partitions the sequence of EXI events into a sequence of one or more non-overlapping blocks. Each block preceding the final block contains the minimum set of consecutive events that result in exactly [blockSize](#key-blockSizeOption) *values* in its value channels (see [**9.2.2 Value Channels**](#ValueChannels)), where blockSize is the block size of the EXI stream (see [**5.4 EXI Options**](#options)). The final block contains
less than the minimum set of consecutive events that result in blockSize *values* in its value channels.

### 9.2 Channels

Events inside each block are multiplexed into channels. The first channel of each block is the structure channel described in Section [**9.2.1 Structure Channel**](#StructureChannel). The remaining channels in each block are value channels described in Section [**9.2.2 Value Channels**](#ValueChannels).
The diagram below presents an exemplary view of the transformation in which events within a block are multiplexed into channels in one way and channels are demultiplexed into events in the other way.

![Multiplexing EXI events into channels](channels.png)

*Figure 9-2. Multiplexing EXI events into channels*

#### 9.2.1 Structure Channel

The structure channel of each block defines the overall order and structure of the events in that block. It contains the [event codes](#key-eventcode) and associated content for each event in the block, except for Attribute (AT) and Character (CH)
[*values*](#key-valueContentItem),
which are stored in the value channels. In addition, there are two kinds of attribute events whose *values* are stored in the structure channel instead of in value channels. The *value* of each xsi:type attribute is stored in the structure channel.
The *value* of each xsi:nil attribute that matches a schema-informed grammar production
that does not include the AT (\*) [untyped value] terminal is also stored in the structure channel. These attribute events are intrinsic to the grammar system thus are essential in processing the structure channel because their values affect the grammar to be used for processing the rest of the elements on which they appear. All [event codes](#key-eventcode) and content in the structure stream occur in the same order as they occur in the EXI event sequence.

#### 9.2.2 Value Channels

The *values* of the Attribute (AT) and Character (CH) events in each block are organized into separate channels based on the *qname* of the associated attribute or element. Specifically, the *value* of each Attribute (AT) event is placed in the channel identified by the *qname* of the Attribute and the *value* of each Character (CH) event is placed in the channel identified by the *qname* of its parent Start Element (SE) event. Each block contains exactly one channel for each distinct element or attribute *qname* that occurs in the block. The *values* in each channel occur in the order they occur in the EXI event sequence.

### 9.3 Compressed Streams

The channels in a block are further organized into compressed streams. Smaller channels are combined into the same compressed stream, while others are each compressed separately. Below are the rules applied within the scope of a block used to determine the channels to be combined together, the order of the compressed streams and the order amongst the channels that are combined into the same compressed stream.

If the value channels of the block contain at most 100 *values*, the block will contain only 1 compressed stream containing the structure channel followed by all of the value channels. The order of the value channels within the compressed stream is defined by the order in which the first *value* in each channel occurs in the EXI event sequence.

If the value channels of the block contain more than 100 *values*, the first compressed stream contains only the structure channel. The second compressed stream contains all value channels that contain at most 100 *values*. And the remaining compressed streams each contain only one channel, each having more than 100 *values*. The order of the value channels within the second compressed stream is defined by the order in which the first *value* in each channel occurs in the EXI event sequence. Similarly, the order of the compressed streams following the second compressed stream in the block is defined by the order in which the first *value* of the channel inside each compressed stream occurs in the EXI event sequence.

**Note:**

EXI compression changes the order in which [event codes](#key-eventcode) and *value*s are read and written to and from an EXI stream.
[EXI processors](#key-exiprocessor) must encode and decode *value*s in this revised order so order sensitive constructs like the string table (see [**7.3 String Table**](#stringTable)) work properly.

When the value of the [compression](#key-compressionOption) option is set to true, each compressed stream in a block is stored using the standard DEFLATE Compressed Data Format defined by RFC 1951 [[IETF RFC 1951]](#RFC1951). Otherwise, when the value of the [alignment](#key-alignmentOption)  option is set to [pre-compression](#key-precompression), each compressed stream in a block is stored directly without the DEFLATE algorithm.

**Note:**

Some EXI events have zero-byte representations and are not explicitly represented in the EXI stream. If all the events in a channel have zero-byte representations, the channel has a zero-byte representation and is not explicitly represented in a compressed stream. Implementations must take care to avoid creating an empty DEFLATE stream when all the channels that would have otherwise been organized into a compressed stream are implicit. E.g., this can occur if the final block contains only zero-length EE and ED events.

## 10. Conformance

### 10.1 EXI Stream Conformance

[Definition:]A **conformant EXI stream** consists of a sequence of octets that follows the syntax of [EXI stream](#key-existream) that is defined in this document.
[Definition:]
EXI format provides a way to involve user-defined datatype representations in EXI streams processing, which is an extension point that, when used in conjunction with relevant datatype representations specifications external to this document, leads to the formulation of **Extended EXI streams**.

Conformance of extended EXI streams is relative to the syntax defined by the relevant user-defined datatype representations specifications. The definitions of user-defined datatype representations syntax are out of the scope of this document.
[Definition:]
An extended EXI stream is a **conformant extended EXI stream** if replacing value items represented using user-defined datatype representations with their intrinsic representations would make the stream a [conformant EXI stream](#key-conformantExiStream).
An extended EXI stream described as an "EXI stream with regards to datatype representations *S* " where *S* is the set of datatype representations can be processed by an [EXI stream decoder](#key-exidecoder) only if the processor has the shared knowledge about each one of the datatype representations in the set *S*.

The structural syntax of [EXI streams](#key-existream) and [extended EXI streams](#key-extendedExiStream) is described by the abstract EXI grammar system defined in this document. Although this document specifies the normative way in which XML Schema schemas are mapped into the EXI grammar system to make schema-informed grammars, EXI allows the use of other schema languages to process EXI streams or extended EXI streams so far as there is a well known EXI grammar binding of the schema language and the binding preserves the semantics of the EXI grammar system. EXI streams or extended EXI streams generated using schemas of such schema language are still conformant. The definitions of grammar bindings for schema languages other than XML Schema are out of the scope of this document, and each schema language community is encouraged to define its own binding in order to make it possible to harness the utmost efficiency out of EXI when schemas of the language are available.

### 10.2 EXI Processor Conformance

The conformance of EXI Processors is defined separately for each of the two processor roles, [EXI stream encoders](#key-exiencoder) and [EXI stream decoders](#key-exidecoder); the conformance of the former is described in terms of the conformance of the [EXI streams](#key-existream) or [extended EXI streams](#key-extendedExiStream) that they produce, while that of the latter is based on the set of format features that EXI stream decoders are prepared
for in the processing of
[conformant EXI streams](#key-conformantExiStream) or [conformant extended EXI streams](#key-conformantExtendedExiStream).

An [EXI stream encoder](#key-exiencoder) is conformant if and only if it is capable of generating [conformant EXI streams](#key-conformantExiStream) or [conformant extended EXI streams](#key-conformantExtendedExiStream) given any input structured data it is made to work on.
On the other hand, [EXI stream decoders](#key-exidecoder) MUST support all format features described in this document as they are explained, except for the capability of handling
[Datatype Representation Map](#key-datatypeRepresentationMaps)
which is an optional feature.
EXI stream decoders that do not implement
[Datatype Representation Map](#key-datatypeRepresentationMaps)
feature MUST report an error with a meaningful message upon encountering a ["datatypeRepresentationMap"](#key-datatypeRepresentationOption) element while processing [EXI options documents](#key-optionsDoc) in [EXI headers](#key-exiheader).

Except where required for interoperability with limited computing platforms (e.g, mobile and embedded devices), this specification avoids placing arbitrary limits on the magnitude of specific numeric values required for implementation. So, in theory it is possible for EXI grammars, event codes, strings, enumeration lists, etc. to be arbitrarily large. In practice, however, it is not the intent of this specification to require conforming implementations to adopt exotic or inefficient numeric representations for handling arbitrarily large EXI documents and grammars on specific platforms.

## A References

### A.1 Normative References

IETF RFC 1951
:   [DEFLATE Compressed Data Format Specification version 1.3](http://www.ietf.org/rfc/rfc1951.txt), P. Deutsch, Author. Internet
    Engineering Task Force, May 1996. Available at
    http://www.ietf.org/rfc/rfc1951.txt.

IETF RFC 2119
:   [Key words for use in RFCs to Indicate
    Requirement Levels](http://www.ietf.org/rfc/rfc2119.txt), S. Bradner, Author. Internet
    Engineering Task Force, June 1999. Available at
    http://www.ietf.org/rfc/rfc2119.txt.

IETF RFC 3023
:   [XML Media Types](http://www.ietf.org/rfc/rfc3023.txt),
    M. Murata, S. St.Laurent and D. Kohn, Author. Internet
    Engineering Task Force, January 2001. Available at
    http://www.ietf.org/rfc/rfc3023.txt.

ISO/IEC 10646
:   ISO/IEC 10646-1:2000. Information technology — Universal Multiple-Octet Coded Character Set (UCS) — Part 1: Architecture and Basic Multilingual Plane and ISO/IEC 10646-2:2001. Information technology — Universal Multiple-Octet Coded Character Set (UCS) — Part 2: Supplementary Planes, as, from time to time, amended, replaced by a new edition or expanded by the addition of new parts. [Geneva]: International Organization for Standardization. (See <http://www.iso.org> for the latest version.)

UNICODE
:   [The Unicode Standard](http://www.unicode.org/), The Unicode Consortium

XML 1.0
:   [Extensible Markup Language (XML) 1.0 (Fifth Edition)](https://www.w3.org/TR/2008/REC-xml-20081126/),
    T. Bray, J. Paoli, C. M. Sperberg-McQueen, E. Maler, and F. Yergeau, Editors.
    World Wide Web Consortium, 10 February 1998, revised 26 November 2008.
    This version is http://www.w3.org/TR/2008/REC-xml-20081126.
    The latest version is available at
    [http://www.w3.org/TR/REC-xml](https://www.w3.org/TR/REC-xml/).

XML 1.1
:   [Extensible Markup Language (XML) 1.1 (Second Edition)](https://www.w3.org/TR/2006/REC-xml11-20060816/),
    T. Bray, J. Paoli, C. M. Sperberg-McQueen, E. Maler, F. Yergeau, and J. Cowan, Editors.
    World Wide Web Consortium, 04 February 2004, revised 16 August 2006.
    This version is http://www.w3.org/TR/2006/REC-xml11-20060816.
    The latest version is available at
    [http://www.w3.org/TR/xml11](https://www.w3.org/TR/xml11/).

Namespaces in XML 1.0
:   [Namespaces in XML 1.0 (Third Edition)](https://www.w3.org/TR/2009/REC-xml-names-20091208/),
    T. Bray, D. Hollander, A. Layman, R. Tobin, and H. Thompson, Editors.
    World Wide Web Consortium, 14 January 1999, revised 8 December 2009.
    This version is http://www.w3.org/TR/2009/REC-xml-names-20091208.
    The latest version is available at
    [http://www.w3.org/TR/xml-names/](https://www.w3.org/TR/xml-names/).

Namespaces in XML 1.1
:   [Namespaces in XML 1.1 (Second Edition)](https://www.w3.org/TR/2006/REC-xml-names11-20060816/),
    T. Bray, D. Hollander, A. Layman, and R. Tobin, Editors.
    World Wide Web Consortium, 4 February 2004, revised 16 August 2006.
    This version is http://www.w3.org/TR/2006/REC-xml-names11-20060816.
    The latest version is available at
    [http://www.w3.org/TR/xml-names11/](https://www.w3.org/TR/xml-names11/).

XML Information Set
:   [XML Information Set (Second Edition)](https://www.w3.org/TR/2004/REC-xml-infoset-20040204/),
    J. Cowan and R. Tobin, Editors. World Wide Web Consortium,
    24 October 2001, revised 4 February 2004.
    This version is http://www.w3.org/TR/2004/REC-xml-infoset-20040204.
    The latest version is available at
    [http://www.w3.org/TR/xml-infoset](https://www.w3.org/TR/xml-infoset/).

XML Schema Structures
:   [XML Schema Part 1: Structures Second
    Edition](https://www.w3.org/TR/2004/REC-xmlschema-1-20041028/), H. Thompson, D. Beech, M. Maloney, and
    N. Mendelsohn, Editors. World Wide Web Consortium, 2 May
    2001, revised 28 October 2004.
    This version is http://www.w3.org/TR/2004/REC-xmlschema-1-20041028.
    The latest version is available at
    [http://www.w3.org/TR/xmlschema-1](https://www.w3.org/TR/xmlschema-1/).

XML Schema Datatypes
:   [XML Schema Part 2: Datatypes Second
    Edition](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/), P. Byron and A. Malhotra,
    Editors. World Wide Web Consortium, 2 May 2001, revised 28
    October 2004.
    This version is http://www.w3.org/TR/2004/REC-xmlschema-2-20041028.
    The latest version is available at
    [http://www.w3.org/TR/xmlschema-2](https://www.w3.org/TR/xmlschema-2/).

### A.2 Other References

Efficient XML
:   [Efficient XML](https://www.w3.org/TR/2007/WD-exi-measurements-20070725/#contributions-efx), part of [[EXI Measurements Note]](#eximeas) independently referenced.
    The latest version is available at
    [http://www.w3.org/TR/exi-measurements/#contributions-efx](https://www.w3.org/TR/exi-measurements/#contributions-efx).

EXI Evaluation Note
:   [Efficient XML Interchange Evaluation](https://www.w3.org/TR/2008/WD-exi-evaluation-20080728/),
    Carine Bournez, Editor.
    World Wide Web Consortium.
    The latest version is available at
    [http://www.w3.org/TR/exi-evaluation/](https://www.w3.org/TR/exi-evaluation/).

EXI Impacts Note
:   [Efficient XML Interchange (EXI) Impacts](https://www.w3.org/TR/2008/WD-exi-impacts-20080903/),
    Jaakko Kangasharju, Editor.
    World Wide Web Consortium.
    The latest version is available at
    [http://www.w3.org/TR/exi-impacts/](https://www.w3.org/TR/exi-impacts/).

EXI Measurements Note
:   [Efficient XML Interchange Measurements Note](https://www.w3.org/TR/2007/WD-exi-measurements-20070725/),
    Greg White, Jaakko Kangasharju, Don Brutzman and Stephen Williams, Editors.
    World Wide Web Consortium.
    The latest version is available at
    [http://www.w3.org/TR/exi-measurements/](https://www.w3.org/TR/exi-measurements/).

EXI Primer
:   [Efficient XML Interchange (EXI) Primer](https://www.w3.org/TR/2009/WD-exi-primer-20091208/),
    Daniel Peintner, Santiago Pericas-Geertsen, Editors.
    World Wide Web Consortium.
    The latest version is available at
    [http://www.w3.org/TR/exi-primer/](https://www.w3.org/TR/exi-primer/).

Greibach Normal Form
:   A New Normal-Form Theorem for Context-Free Phrase Structure Grammars
    ,
    Sheila A. Greibach, Author.
    Journal of the ACM Volume 12  Issue 1, January 1965, pp. 42–52.

Huffman Coding
:   [A Method for the Construction of
    Minimum-Redundancy Codes](http://compression.ru/download/articles/huff/huffman_1952_minimum-redundancy-codes.pdf), D. A. Huffman,
    Author. Proceedings of the I.R.E., September 1952, pp.
    1098-1102.

IEEE 754-2008
:   [IEEE Standard for Floating-Point Arithmetic](http://ieeexplore.ieee.org/xpl/freeabs_all.jsp?arnumber=4610935)

ISO/IEC 19757-2:2008
:   [Document Schema Definition Language (DSDL) -- Part 2: Regular-grammar-based validation -- RELAX NG](http://www.iso.org/iso/iso_catalogue/catalogue_tc/catalogue_detail.htm?csnumber=52348)

SOAP 1.2
:   [SOAP Version 1.2 Part 1: Messaging Framework (Second Edition)](https://www.w3.org/TR/2007/REC-soap12-part1-20070427/),
    M. Gudgin, M. Hadley, N. Mendelsohn,
    J-J. Moreau, H. Frystyk Nielsen, A. Karmarkar, and Y. Lafon, Editors. World Wide Web
    Consortium, 24 June 2003, revised 27 April 2007.
    This version is http://www.w3.org/TR/2007/REC-soap12-part1-20070427/᠎.
    The latest version is available at
    [http://www.w3.org/TR/soap12-part1/](https://www.w3.org/TR/soap12-part1/).

XBC Measurement Methodologies
:   [XML Binary Characterization Measurement
    Methodologies](https://www.w3.org/TR/2005/NOTE-xbc-measurement-20050331/), S. D. Williams and P. Haggar,
    Editors. World Wide Web Consortium, 31 March 2005.
    This version is http://www.w3.org/TR/2005/NOTE-xbc-measurement-20050331/.
    The latest version is available at
    [http://www.w3.org/TR/xbc-measurement](https://www.w3.org/TR/xbc-measurement/).

XBC Use Cases
:   [XML Binary Characterization Use Cases](https://www.w3.org/TR/2005/NOTE-xbc-use-cases-20050331/),
    Mike Cokus and Santiago Pericas-Geertsen, Editors.
    World Wide Web Consortium, 31 March 2005.
    This version is http://www.w3.org/TR/2005/NOTE-xbc-use-cases-20050331/.
    The latest version is available at
    [http://www.w3.org/TR/xbc-use-cases](https://www.w3.org/TR/xbc-use-cases/).

XBC Properties
:   [XML Binary Characterization Properties](https://www.w3.org/TR/2005/NOTE-xbc-properties-20050331/),
    Mike Cokus and Santiago Pericas-Geertsen, Editors.
    World Wide Web Consortium, 31 March 2005.
    This version is http://www.w3.org/TR/2005/NOTE-xbc-properties-20050331/
    The latest version is available at
    [http://www.w3.org/TR/xbc-properties/](https://www.w3.org/TR/xbc-properties/).

## B Infoset Mapping

This appendix contains the mappings between the XML Information
Set [[XML Information Set]](#XMLInfoset) model and the EXI format.
Starting from the document information item,
each **information item** definition is mapped to its respective
unordered set of EXI event types
(see [Table 4-1](#eventTypes)).
The actual order amongst information set items when it is relevant reflects the occurrence order of EXI events or their references in an EXI stream that correlate to the infoset items. As used in the XML Information
Set specification, the Infoset property names are shown in square
brackets, **[thus]**.

**Note:**

As has been prescribed in section [**2. Design Principles**](#principles), EXI is designed to be compatible with the XML Information Set. While this approach is both legitimate and practical for designing a succinct format interoperable with XML family of specifications and technologies, it entails that some lexical constructs of XML not recognized by the XML Information Set are not represented by EXI, either. Examples of such unrepresented lexical constructs of XML include white space outside the document element, white space within tags, the kind of quotation marks (single or double) used to quote attribute values, and the boundaries of CDATA marked sections.

No constructs in EXI format facilitate the representation of
**[character encoding scheme]**,
**[standalone]** and **[version]**
properties which are available in the definition of Document Information Item of XML Information Set
(see [**B.1 Document Information Item**](#DocumentInformationItem)). EXI is made agnostic about
**[character encoding scheme]** and **[version]**
properties as they are in XML Information Set, and considers them to be the properties of
XML serializers in use. EXI forgoes **[standalone]** property
because simply having no references to any external markup declarations practically
serves the purpose with less complexity.

### B.1 Document Information Item

A document information item maps to a pair of
Start Document (SD)
and
End Document (ED) events
with each of its properties subject to further mapping as shown in the following table.

Table B-1. Mapping between the document information item properties to EXI event types

| Property | EXI event types |
| --- | --- |
| **[children]** | CM\* PI\* DT? [SE, EE] |
| **[document element]** | [SE, EE] |
| **[notations]** | Computed based on *text* content item of DT to which each notation information set item maps. |
| **[unparsed entities]** | Computed based on *text* content item of DT to which each unparsed entity information set item maps. |
| **[base URI]** | The base URI of the EXI stream |
| **[character encoding scheme]** | N/A |
| **[standalone]** | Not available |
| **[version]** | Not available |
| **[all declarations processed]** | True if all declarations contained directly or indirectly in DT are processed, otherwise false, which is the processor quality as opposed to the information provided by the format. |

### B.2 Element Information Items

An element information item maps to a pair of a
Start Element (SE)
event and the corresponding
End Element (EE)
event with each of its properties subject to further mapping as shown in the following table.

Table B-2. Mapping of the element information item properties to EXI event types

| Property | EXI event types |
| --- | --- |
| **[namespace name]** | SE |
| **[local name]** | SE |
| **[prefix]** | SE |
| **[children]** | [SE, EE]\* PI\* CM\* CH\* ER\* |
| **[attributes]** | AT\* |
| **[namespace attributes]** | NS\* |
| **[in-scope namespaces]** | The namespace information items computed using the **[namespace attributes]** properties of this information item and its ancestors |
| **[base URI]** | The base URI of the element information item |
| **[parent]** | Computed based on the last SE event encountered that did not get a matching EE event if any, or computed based on the SD event |

### B.3 Attribute Information Item

An attribute information item maps to an
Attribute (AT)
event with each of its properties subject to further mapping as shown in the following table.

Table B-3. Mapping of the attribute information item properties to EXI event types

| Property | EXI event types |
| --- | --- |
| **[namespace name]** | AT |
| **[local name]** | AT |
| **[prefix]** | AT |
| **[normalized value]** | The *value* of AT |
| **[specified]** | True if the item maps to AT, otherwise false |
| **[attribute type]** | Computed based on AT and DT |
| **[references]** | Computed based on **[attribute type]** and *value* of AT |
| **[owner element]** | Computed based on the last SE event encountered that did not get a matching EE event |

### B.4 Processing Instruction Information Item

A processing instruction information maps to a
Processing Instruction (PI)
event with each of its properties subject to further mapping as shown in the following table.

Table B-4. Mapping of the processing instruction information item properties to EXI event types

| Property | EXI event types |
| --- | --- |
| **[target]** | PI |
| **[content]** | PI |
| **[base URI]** | The base URI of the processing information item |
| **[notation]** | Computed based on the availability of the internal DTD subset |
| **[parent]** | Computed based on the last SE event encountered that did not get a matching EE event type |

### B.5 Unexpanded Entity Reference Information item

An unexpanded entity reference information item maps to an
Entity Reference (ER) event
with each of its properties subject to further mapping as shown in the following table.

Table B-5. Mapping of the entity reference information item properties to
the EXI event types

| Property | EXI event types |
| --- | --- |
| **[name]** | ER |
| **[system identifier]** | Based on the availability of the internal DTD subset |
| **[public identifier]** | Based on the availability of the internal DTD subset |
| **[declaration base URI]** | The base URI of the unexpanded entity reference information item |
| **[parent]** | Computed based on the last SE event encountered that did not get a matching EE event type |

### B.6 Character Information item

A character information item maps to the individual characters contained in a
Characters (CH)
event following a SE event that did not get a matching EE event.

Table B-6. Mapping of the character information item properties and the EXI event types

| Property | EXI event types |
| --- | --- |
| **[character code]** | Each character in CH |
| **[element content whitespace]** | Computed based on **[parent]** and DT |
| **[parent]** | Computed based on the last SE event encountered that did not get a matching EE event |

### B.7 Comment Information item

A comment information item maps to a
Comment (CM)
event with each of its properties subject to further mapping as shown in the following table.

Table B-7. Mapping of the comment information item properties and the EXI event types

| Property | EXI event types |
| --- | --- |
| **[content]** | *text* content item of CM |
| **[parent]** | Computed based on the last SE event encountered that did not get a matching EE event, or the SD event |

### B.8 Document Type Declaration Information item

A document type declaration information item maps to a
DOCTYPE (DT)
event with each of its properties subject to further mapping as shown in the following table.

Table B-8. Mapping of the document type declaration information item properties to the EXI event types

| Property | EXI event types |
| --- | --- |
| **[system identifier]** | DT |
| **[public identifier]** | DT |
| **[children]** | Computed based on *text* content item of DT |
| **[parent]** | Computed based on the SD event |

### B.9 Unparsed Entity Information Item

An unparsed entity information item maps to part of the
*text* content item of
DOCTYPE (DT)
event with each of its properties subject to further mapping as shown in the following table.

Table B-9. Mapping of the unparsed entity information item properties to EXI event types

| Property | EXI event types |
| --- | --- |
| **[name]** | Computed based on *text* content item of DT |
| **[system identifier]** | Computed based on *text* content item of DT |
| **[public identifier]** | Computed based on *text* content item of DT |
| **[declaration base URI]** | The base URI of the unparsed entity information item |
| **[notation name]** | Computed based on *text* content item of DT |
| **[notation]** | Computed based on *text* content item of DT |

### B.10 Notation Information Item

An notation information item maps to part of the
*text* content item of
DOCTYPE (DT)
event with each of its properties subject to further mapping as shown in the following table.

Table B-10. Mapping of the notation information item properties to EXI event types

| Property | EXI event types |
| --- | --- |
| **[name]** | Computed based on *text* content item of DT |
| **[system identifier]** | Computed based on *text* content item of DT |
| **[public identifier]** | Computed based on *text* content item of DT |
| **[declaration base URI]** | The base URI of the notation information item |

### B.11 Namespace Information Item

An namespace information item
maps to a Namespace Declaration (NS)
event with each of its properties subject to further mapping as shown in the following table.

Table B-11. Mapping of the namespace information item properties to EXI event types

| Property | EXI event types |
| --- | --- |
| **[prefix]** | NS |
| **[namespace name]** | NS |

## C XML Schema for EXI Options Document

The following schema describes the EXI options header. It is
designed to produce smaller headers for option combinations used when
compactness is critical.

```

<xsd:schema targetNamespace="http://www.w3.org/2009/exi"
            xmlns:xsd="http://www.w3.org/2001/XMLSchema"
            elementFormDefault="qualified">

  <xsd:element name="header">
    <xsd:complexType>
      <xsd:sequence>
        <xsd:element name="lesscommon" minOccurs="0">
          <xsd:complexType>
            <xsd:sequence>
              <xsd:element name="uncommon" minOccurs="0">
                <xsd:complexType>
                  <xsd:sequence>
                    <xsd:any namespace="##other" minOccurs="0" maxOccurs="unbounded"
                             processContents="skip" />
                    <xsd:element name="alignment" minOccurs="0">
                      <xsd:complexType>
                        <xsd:choice>
                          <xsd:element name="byte">
                            <xsd:complexType />
                          </xsd:element>
                          <xsd:element name="pre-compress">
                            <xsd:complexType />
                          </xsd:element>
                        </xsd:choice>
                      </xsd:complexType>
                    </xsd:element>
                    <xsd:element name="selfContained" minOccurs="0">
                      <xsd:complexType />
                    </xsd:element>
                    <xsd:element name="valueMaxLength" minOccurs="0">
                      <xsd:simpleType>
                        <xsd:restriction base="xsd:unsignedInt" />
                      </xsd:simpleType>
                    </xsd:element>
                    <xsd:element name="valuePartitionCapacity" minOccurs="0">
                      <xsd:simpleType>
                        <xsd:restriction base="xsd:unsignedInt" />
                      </xsd:simpleType>
                    </xsd:element>
                    <xsd:element name="datatypeRepresentationMap"
                                 minOccurs="0" maxOccurs="unbounded">
                      <xsd:complexType>
                        <xsd:sequence>
                          <!-- schema datatype -->
                          <xsd:any namespace="##other" processContents="skip" />
                          <!-- datatype representation -->
                          <xsd:any processContents="skip" />
                        </xsd:sequence>
                      </xsd:complexType>
                    </xsd:element>
                  </xsd:sequence>
                </xsd:complexType>
              </xsd:element>
              <xsd:element name="preserve" minOccurs="0">
                <xsd:complexType>
                  <xsd:sequence>
                    <xsd:element name="dtd" minOccurs="0">
                      <xsd:complexType />
                    </xsd:element>
                    <xsd:element name="prefixes" minOccurs="0">
                      <xsd:complexType />
                    </xsd:element>
                    <xsd:element name="lexicalValues" minOccurs="0">
                      <xsd:complexType />
                    </xsd:element>
                    <xsd:element name="comments" minOccurs="0">
                      <xsd:complexType />
                    </xsd:element>
                    <xsd:element name="pis" minOccurs="0">
                      <xsd:complexType />
                    </xsd:element>
                  </xsd:sequence>
                </xsd:complexType>
              </xsd:element>
              <xsd:element name="blockSize" minOccurs="0">
                <xsd:simpleType>
                  <xsd:restriction base="xsd:unsignedInt">
                    <xsd:minInclusive value="1" />
                  </xsd:restriction>
                </xsd:simpleType>
              </xsd:element>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:element>
        <xsd:element name="common" minOccurs="0">
          <xsd:complexType>
            <xsd:sequence>
              <xsd:element name="compression" minOccurs="0">
                <xsd:complexType />
              </xsd:element>
              <xsd:element name="fragment" minOccurs="0">
                <xsd:complexType />
              </xsd:element>
              <xsd:element name="schemaId" minOccurs="0" nillable="true">
                <xsd:simpleType>
                  <xsd:restriction base="xsd:string" />
                </xsd:simpleType>
              </xsd:element>
            </xsd:sequence>
          </xsd:complexType>
        </xsd:element>
        <xsd:element name="strict" minOccurs="0">
          <xsd:complexType />
        </xsd:element>
      </xsd:sequence>
    </xsd:complexType>
  </xsd:element>

  <!-- Built-in EXI Datatype IDs for use in datatype representation maps -->
  <xsd:simpleType name="base64Binary">
     <xsd:restriction base="xsd:base64Binary"/>
  </xsd:simpleType>
  <xsd:simpleType name="hexBinary" >
     <xsd:restriction base="xsd:hexBinary"/>
  </xsd:simpleType>
  <xsd:simpleType name="boolean" >
     <xsd:restriction base="xsd:boolean"/>
  </xsd:simpleType>
  <xsd:simpleType name="decimal" >
     <xsd:restriction base="xsd:decimal"/>
  </xsd:simpleType>
  <xsd:simpleType name="double" >
     <xsd:restriction base="xsd:double"/>
  </xsd:simpleType>
  <xsd:simpleType name="integer" >
     <xsd:restriction base="xsd:integer"/>
  </xsd:simpleType>
  <xsd:simpleType name="string" >
     <xsd:restriction base="xsd:string"/>
  </xsd:simpleType>
  <xsd:simpleType name="dateTime" >
     <xsd:restriction base="xsd:dateTime"/>
  </xsd:simpleType>
  <xsd:simpleType name="date" >
     <xsd:restriction base="xsd:date"/>
  </xsd:simpleType>
  <xsd:simpleType name="time" >
     <xsd:restriction base="xsd:time"/>
  </xsd:simpleType>
  <xsd:simpleType name="gYearMonth" >
     <xsd:restriction base="xsd:gYearMonth"/>
  </xsd:simpleType>
  <xsd:simpleType name="gMonthDay" >
     <xsd:restriction base="xsd:gMonthDay"/>
  </xsd:simpleType>
  <xsd:simpleType name="gYear" >
     <xsd:restriction base="xsd:gYear"/>
  </xsd:simpleType>
  <xsd:simpleType name="gMonth" >
     <xsd:restriction base="xsd:gMonth"/>
  </xsd:simpleType>
  <xsd:simpleType name="gDay" >
     <xsd:restriction base="xsd:gDay"/>
  </xsd:simpleType>

  <!-- Qnames reserved for future use in datatype representation maps -->
  <xsd:simpleType name="ieeeBinary32" >
     <xsd:restriction base="xsd:float"/>
  </xsd:simpleType>
  <xsd:simpleType name="ieeeBinary64" >
     <xsd:restriction base="xsd:double"/>
  </xsd:simpleType>
</xsd:schema>
```

**Note:**

The [qnames](#key-qname) exi:ieeeBinary32 and exi:ieeeBinary64 defined above are reserved for future use in Datatype Representation Maps to identify the 32-bit and 64-bit Binary Interchange Formats defined by the IEEE 754-2008 standard [[IEEE 754-2008]](#ieeefloat).

## D Initial Entries in String Table Partitions

### D.1 Initial Entries in Uri Partition

The following table lists the entries that are initially populated in uri partitions, where partition name URI denotes that they are entries in the uri partition.

Table D-1. Initial values in *uri* partition

| Partition | Compact ID | String Value |
| --- | --- | --- |
| URI | 0 | "" [empty string] |
| URI | 1 | "http://www.w3.org/XML/1998/namespace" |
| URI | 2 | "http://www.w3.org/2001/XMLSchema-instance" |

When XML Schemas are used to inform the grammars for processing EXI body, there is an additional entry that is appended to the uri partition,
regardless of the XML Schema in use.

Table D-2. Additional entry when XML Schemas are used

| Partition | Compact ID | String Value |
| --- | --- | --- |
| URI | 3 | "http://www.w3.org/2001/XMLSchema" |

Additionally, when XML Schemas are used, the uri partition is also pre-populated with some of the namespace URIs used in the schemas. Section [**7.3.1 String Table Partitions**](#stringTablePartitions) describes the way this has to be done. All string values in uri partition are unique.

### D.2 Initial Entries in Prefix Partitions

The following table lists the entries that are initially populated in prefix partitions,
where XML-PF represents the partition for *prefixes* in
the `"http://www.w3.org/XML/1998/namespace"` namespace and XSI-PF
represents the partition for *prefixes* in the
`"http://www.w3.org/2001/XMLSchema-instance"` namespace.

Table D-3. Initial
*prefix* string table entries

| Partition | Compact ID | String Value |
| --- | --- | --- |
| "" | 0 | "" [empty string] |
| XML-PF | 0 | "xml" |
| XSI-PF | 0 | "xsi" |

### D.3 Initial Entries in Local-Name Partitions

The following tables list the string values that are initially populated and made available
in local-name partitions, where XML‑NS represents the partition for *local-names*
in the `"http://www.w3.org/XML/1998/namespace"` namespace, XSI‑NS
represents the partition for *local-names* in the
`"http://www.w3.org/2001/XMLSchema-instance"` namespace, and XSD‑NS
represents the partition for *local-names* in the
`"http://www.w3.org/2001/XMLSchema"` namespace.

Table D-4.
String values initially available in XML‑NS and XSI‑NS partition

| Partition | String Values |
| --- | --- |
| XML‑NS | "base", "id", "lang", "space" |
| XSI‑NS | "nil", "type" |

When XML Schemas are used to inform the grammars for processing EXI body, those string values listed in the next table are available in XSD‑NS partition.

Table D-5.
String values initially available in XSD‑NS partition for schema-informed EXI streams

| Partition | String Values |
| --- | --- |
| XSD‑NS | "ENTITIES", "ENTITY", "ID", "IDREF", "IDREFS", "NCName", "NMTOKEN", "NMTOKENS", "NOTATION", "Name", "QName", "anySimpleType", "anyType", "anyURI", "base64Binary", "boolean", "byte", "date", "dateTime", "decimal", "double", "duration", "float", "gDay", "gMonth", "gMonthDay", "gYear", "gYearMonth", "hexBinary", "int", "integer", "language", "long", "negativeInteger", "nonNegativeInteger", "nonPositiveInteger", "normalizedString", "positiveInteger", "short", "string", "time", "token", "unsignedByte", "unsignedInt", "unsignedLong", "unsignedShort" |

Additionally, when a schema is provided, the string table is also pre-populated with the local-name of each attribute, element and type explicitly declared in the schema, partitioned by namespace URI.

All string values within each partition containing local-names is then sorted lexicographically. Assign each string value a compact identifier in the sorted order, with the initial identifier number 0 assigned to the first string value, incremented by 1 before each subsequent assignment.

## E Deriving Set of Characters from XML Schema Regular Expressions

XML Schema datatypes specification [[XML Schema Datatypes]](#schema2) defines a [regular expression](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#regexs)XS2 syntax for use in pattern facets of simple type definitions. Pattern facets constrain the set of valid values to those that lexically match the specified regular expression. This section describes the rules for deriving the set of characters allowed in a string value that conforms to a given regular expression in an XML Schema.
In the following description, the term "set-of-chars" is used as the shorthand form of "set of characters".

At the top level,
the XML Schema regular expression
syntax is summarized by the following production excerpted here from [[XML Schema Datatypes]](#schema2). Note the notation used for the numbers that tag the productions. "XSD:" is prefixed to the original numeric tags to make it easier to discern them as belonging to XML Schema specification.

[[XSD:1]](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#regex)XS2  regExp  ::=  branch  (  '|'  branch  )\*

The set-of-chars for a regex that conforms to the syntax above is the union of the set-of-chars defined for each branch. Each branch of a regex is described by the following production:

[[XSD:2]](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#branch)XS2  branch  ::=  piece\*

The set-of-chars for each branch of a regex is the union of the set-of-chars for each piece of the branch. Each piece of a branch is described by the following production:

[[XSD:3]](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#piece)XS2  piece  ::=  atom  quantifier?

The set-of-chars for each piece of a branch is the set-of-chars for the atom portion of the piece. The atom portion of a piece is described by the following production:

[[XSD:9]](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#atom)XS2  atom  ::=  Char  |  charClass  |  (  '('  regExp  ')'  )

The set-of-chars for the atom is the set-of-chars for the Char, charClass or regExp that constitutes the atom.

The set-of-chars for a Char that constitutes an atom contains the single character that matches the [Char expression](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#char)XS2.
The set-of-chars for a charClass that constitutes an atom is the set of characters specified by the [charClass expression](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#charClass) XS2.
The set-of-chars for a regExp sub-expression enclosed in parenthesis that constitutes an atom is the set-of-chars for the regExp itself derived by recursively applying the rule defined above.

For stability and interoperability of restricted character sets across different versions of the Unicode standard, certain pattern facets cannot be used for deriving restricted character sets. In particular, pattern facets that contain one or more [category escapes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#nt-catEsc)XS2, [category complement escapes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#nt-complEsc)XS2 or [multi-character escapes](https://www.w3.org/TR/2004/REC-xmlschema-2-20041028/#nt-MultiCharEsc)XS2 other than \s do not have restricted character sets.

## F Content Coding and Internet Media Type

Two labels are defined for identifying and negotiating the use of EXI for representing XML information in higher-level protocols. They serve two distinct roles. One is for content coding and the other is for internet media type.

### F.1 Content Coding

The content-coding value "exi" is registered with the Internet Assigned Numbers Authority (IANA) for use with EXI. Protocols that can identify and negotiate the content coding of
XML
information independent of its media type,
SHOULD use the content coding "exi" (case-insensitive) to convey the acceptance or actual use of EXI encoding for XML information.

### F.2 Internet Media Type

A new media type registration "application/exi" described below is being proposed for community review, with the intent to eventually submit it to the IESG for review, approval, and registration with IANA.

Type name:
:   application

Subtype name:
:   exi

Required parameters:
:   none

Optional parameters:
:   none

Encoding considerations:
:   binary

Security considerations:
:   When used as an XML replacement in an application, EXI shares
    the same security concerns as XML, described in IETF RFC 3023 [[IETF RFC 3023]](#RFC3023),
    section 10.

    In addition to concerns shared with XML, the schema identifier
    refers to information external to the EXI document itself. If
    an attacker is able to substitute another schema in place of
    the intended one, the semantics of the EXI document could be
    changed in some ways. As an example, EXI is sensitive to the
    order of the values in an enumeration. It is not known whether
    such an attack is possible on the actual structure of the
    document.

    Also, EXI supports user-defined datatype representations, and such
    representations, if present in a document and purportedly understood by
    a processor, can be a security weakness. Definitions of these
    representations are expected to be external, often application- or
    industry-specific, so any definition needs to be analyzed carefully from
    the security perspective before being adopted.

Interoperability considerations:
:   The datatype representation map feature of EXI requires
    coordination between the producer and consumer of an EXI
    document, and is not recommended except in controlled
    environments or using standardized datatype representations
    potentially defined in the future.

    EXI permits information necessary to decode a document to be
    omitted with the expectation that such information has been
    communicated out of band. Such omissions hinder
    interoperability in uncontrolled environments.

Published specification:
:   Efficient XML Interchange (EXI) Format 1.0, World Wide Web
    Consortium

Applications that use this media type:
:   No known applications currently use this media type.

Additional information:
:   |  |  |
    | --- | --- |
    |  | |
    | Magic number(s): | |
    |  | The first four octets may be hexadecimal 24 45 58 49 ("$EXI"). The first octet after these, or the first octet of the whole content if they are not present, has its high two bits set to values 1 and 0 in that order. |

    | File extension(s): | |
    | --- | --- |
    |  | .exi |

    | Macintosh file type code(s): | |
    | --- | --- |
    |  | APPL |

    | Consideration of alternatives : | |
    | --- | --- |
    |  | When transferring EXI streams over a protocol that can identify and negotiate the content coding of XML information independent of its media-type, the content-coding should be used to identify and negotiate how the XML information is encoded and the media-type should be used to negotiate and identify what type of information is transferred. |
    |  | |

Person & email address to contact for further information:
:   World Wide Web Consortium <web-human@w3.org>

Intended usage:
:   COMMON

Restrictions on usage:
:   none

Author/Change controller:
:   The EXI specification is the product of the World Wide Web
    Consortium's Efficient XML Interchange Working Group. The W3C
    has change control over this specification.

## G Example Encoding (Non-Normative)

EXI Primer [[EXI Primer]](#exiprimer) contains a section that explains the workings of EXI format using simple example documents. Those examples are intended to serve as a tool to confirm the understanding of the EXI format in action by going through encoding and decoding processes step by step.

## H Schema-informed Grammar Examples (Non-Normative)

As an example to exercise the process to produce schema-informed element grammars, consider the following XML Schema fragment declaring two complex-typed elements, <product> and <order>:

*Example H-1. Example XML Schema fragment*

```

<xs:element name="product">
  <xs:complexType>
    <xs:sequence maxOccurs="2">
      <xs:element name="description" type="xs:string" minOccurs="0"/>
      <xs:element name="quantity" type="xs:integer" />
      <xs:element name="price" type="xs:float" />
    </xs:sequence>
    <xs:attribute name="sku" type="xs:string" use="required" />
    <xs:attribute name="color" type="xs:string" use="optional" />
  </xs:complexType>
</xs:element>

<xs:element name="order">
  <xs:complexType>
    <xs:sequence>
      <xs:element ref="product" maxOccurs="unbounded" />
    </xs:sequence>
  </xs:complexType>
</xs:element>
```

Section [**H.1 Proto-Grammar Examples**](#exampleProtoGrammars) guides you through the process of
generating
EXI proto-grammars from the schema components available in the example schema above. EXI grammars in the normalized form that correspond to the proto-grammars are shown in section [**H.2 Normalized Grammar Examples**](#exampleNormGrammars). Section [**H.3 Complete Grammar Examples**](#exampleCompleteGrammars) shows the complete EXI grammars for elements <product> and <order>.

### H.1 Proto-Grammar Examples

Grammars for element declaration terms "description", "quantity" and "price" are as follows. See section [**8.5.4.1.6 Element Terms**](#elementTerms) for the rules used to
generate grammars for element terms.

|  |
| --- |
|  |

| *Term\_description* | | |
| --- | --- | --- |
|  | | |
|  | *Term\_description*0 : | |
|  |  | SE(*"description"*) *Term\_description*1 |
|  | | |
|  | *Term\_description*1 : | |
|  |  | EE |
|  | | |

| *Term\_quantity* | | |
| --- | --- | --- |
|  | | |
|  | *Term\_quantity*0 : | |
|  |  | SE(*"quantity"*) *Term\_quantity*1 |
|  | | |
|  | *Term\_quantity*1 : | |
|  |  | EE |
|  | | |

| *Term\_price* | | |
| --- | --- | --- |
|  | | |
|  | *Term\_price*0 : | |
|  |  | SE(*"price"*) *Term\_price*1 |
|  | | |
|  | *Term\_price*1 : | |
|  |  | EE |
|  | | |

The grammar for element particle "description" is
created based on
[*Term\_description*](#termDescription) given { minOccurs } value of 0 and { maxOccurs } value of 1. See section [**8.5.4.1.5 Particles**](#particles) for the rules used to
generate grammars for particles.

|  |
| --- |
|  |

| *Particle\_description* | | |
| --- | --- | --- |
|  | | |
|  | *Term\_description*0 : | |
|  |  | SE(*"description"*) *Term\_description*1 |
|  |  | EE |
|  | | |
|  | *Term\_description*1 : | |
|  |  | EE |
|  | | |

Grammars for element particle "quantity" and "prices" are the same as those of their terms ([*Term\_quantity*](#termQuantity) and [*Term\_price*](#termPrice), respectively) because {minOccurs} and {maxOccurs} are both 1.

|  |
| --- |
|  |

| *Particle\_quantity* | | |
| --- | --- | --- |
|  | | |
|  | *Term\_quantity*0 : | |
|  |  | SE(*"quantity"*) *Term\_quantity*1 |
|  | | |
|  | *Term\_quantity*1 : | |
|  |  | EE |
|  | | |

| *Particle\_price* | | |
| --- | --- | --- |
|  | | |
|  | *Term\_price*0 : | |
|  |  | SE(*"price"*) *Term\_price*1 |
|  | | |
|  | *Term\_price*1 : | |
|  |  | EE |
|  | | |

The grammar for the sequence group term in <product> element declaration is
created based on
the grammars of subordinate particles as follows. See section [**8.5.4.1.8.1 Sequence Model Groups**](#sequenceGroupTerms) for the rules used to
generate grammars for sequence groups.

|  |  |
| --- | --- |
|  | *Term\_sequence* = [*Particle\_description*](#particleDescription) ⊕ [*Particle\_quantity*](#particleQuantity) ⊕ [*Particle\_price*](#particlePrice) |

which yields the following grammars for *Term\_sequence*.

|  |
| --- |
|  |

| *Term\_sequence* | | |
| --- | --- | --- |
|  | | |
|  | *Term\_description*0 : | |
|  |  | SE("description") *Term\_description*1 |
|  |  | *Term\_quantity* 0 |
|  | | |
|  | *Term\_description* 1 : | |
|  |  | *Term\_quantity* 0 |
|  | | |
|  | *Term\_quantity* 0 : | |
|  |  | SE("quantity") *Term\_quantity* 1 |
|  | | |
|  | *Term\_quantity* 1 : | |
|  |  | *Term\_price* 0 |
|  | | |
|  | *Term\_price* 0 : | |
|  |  | SE("price") *Term\_price* 1 |
|  | | |
|  | *Term\_price* 1 : | |
|  |  | EE |
|  | | |

The grammar for the particle that is the content model of element <product>
is created based on
[*Term\_sequence*](#termSequence) (shown above) given {minOccurs} value of 1 and {maxOccurs} value of 2. See section [**8.5.4.1.5 Particles**](#particles) for the rules used to
generate grammars for particles.

|  |
| --- |
|  |

| *Particle\_sequence* | | |
| --- | --- | --- |
|  | | |
|  | *Term\_description*0,0 : | |
|  |  | SE("description") *Term\_description*0,1 |
|  |  | *Term\_quantity*0,0 |
|  | | |
|  | *Term\_description*0,1 : | |
|  |  | *Term\_quantity*0,0 |
|  | | |
|  | *Term\_quantity*0,0 : | |
|  |  | SE("quantity") *Term\_quantity*0,1 |
|  | | |
|  | *Term\_quantity*0,1 : | |
|  |  | *Term\_price*0,0 |
|  | | |
|  | *Term\_price*0,0 : | |
|  |  | SE("price") *Term\_price*0,1 |
|  | | |
|  | *Term\_price*0,1 : | |
|  |  | *Term\_description*1,0 |
|  | | |
|  | *Term\_description*1,0 : | |
|  |  | SE("description") *Term\_description*1,1 |
|  |  | *Term\_quantity*1,0 |
|  |  | EE |
|  | | |
|  | *Term\_description*1,1 : | |
|  |  | *Term\_quantity*1,0 |
|  | | |
|  | *Term\_quantity*1,0 : | |
|  |  | SE("quantity") *Term\_quantity*1,1 |
|  | | |
|  | *Term\_quantity*1,1 : | |
|  |  | *Term\_price*1,0 |
|  | | |
|  | *Term\_price*1,0 : | |
|  |  | SE("price") *Term\_price*1,1 |
|  | | |
|  | *Term\_price*1,1 : | |
|  |  | EE |
|  | | |

Grammars for attribute uses of attributes "sku" and "color" are as follows. See section [**8.5.4.1.4 Attribute Uses**](#attributeUses) for the rules used to
generate grammars for attribute uses.

|  |
| --- |
|  |

| *Use\_sku* | | |
| --- | --- | --- |
|  | | |
|  | *Use\_sku* 0 : | |
|  |  | AT("sku") [schema-typed value] *Use\_sku* 1 |
|  | | |
|  | *Use\_sku* 1 : | |
|  |  | EE |
|  | | |

| *Use\_color* | | |
| --- | --- | --- |
|  | | |
|  | *Use\_color* 0 : | |
|  |  | AT("color") [schema-typed value] *Use\_color* 1 |
|  |  | EE |
|  | | |
|  | *Use\_color* 1 : | |
|  |  | EE |
|  | | |

Note the subtle difference between
the forms of the two
grammars [*Use\_sku*](#useSku) and [*Use\_color*](#useColor).
At the outset of the grammars,
only [*Use\_color*](#useColor) contains a production of which the right-hand side starts with EE, which
is the result of
the difference in their occurrence
requirement
defined in the schema.

Finally, the grammar for the element <product> is
created based on
the grammars of its attribute uses and content model particle as follows. See section [**8.5.4.1.3.2 Complex Type Grammars**](#complexTypeGrammars) for the rules used to
generate grammars for complex types.

|  |  |
| --- | --- |
|  | *ProtoG\_ProductElement* = [*Use\_color*](#useColor) ⊕ [*Use\_sku*](#useSku) ⊕ [*Particle\_sequence*](#particleSequence) |

which yields the following grammar for element <product>.

|  |
| --- |
|  |

| *ProtoG\_ProductElement* | | |
| --- | --- | --- |
|  | | |
|  | *Use\_color* 0 : | |
|  |  | AT("color") [schema-typed value] *Use\_color* 1 |
|  |  | *Use\_sku* 0 |
|  | | |
|  | *Use\_color* 1 : | |
|  |  | *Use\_sku* 0 |
|  | | |
|  | *Use\_sku* 0 : | |
|  |  | AT("sku") [schema-typed value] *Use\_sku* 1 |
|  | | |
|  | *Use\_sku* 1 : | |
|  |  | *Term\_description*0,0 |
|  | | |
|  | *Term\_description*0,0 : | |
|  |  | SE("description") *Term\_description*0,1 |
|  |  | *Term\_quantity*0,0 |
|  | | |
|  | *Term\_description*0,1 : | |
|  |  | *Term\_quantity*0,0 |
|  | | |
|  | *Term\_quantity*0,0 : | |
|  |  | SE("quantity") *Term\_quantity*0,1 |
|  | | |
|  | *Term\_quantity*0,1 : | |
|  |  | *Term\_price*0,0 |
|  | | |
|  | *Term\_price*0,0 : | |
|  |  | SE("price") *Term\_price*0,1 |
|  | | |
|  | *Term\_price*0,1 : | |
|  |  | *Term\_description*1,0 |
|  | | |
|  | *Term\_description*1,0 : | |
|  |  | SE("description") *Term\_description*1,1 |
|  |  | *Term\_quantity*1,0 |
|  |  | EE |
|  | | |
|  | *Term\_description*1,1 : | |
|  |  | *Term\_quantity*1,0 |
|  | | |
|  | *Term\_quantity*1,0 : | |
|  |  | SE("quantity") *Term\_quantity*1,1 |
|  | | |
|  | *Term\_quantity*1,1 : | |
|  |  | *Term\_price*1,0 |
|  | | |
|  | *Term\_price*1,0 : | |
|  |  | SE("price") *Term\_price*1,1 |
|  | | |
|  | *Term\_price*1,1 : | |
|  |  | EE |
|  | | |

The other element declaration <order> can be processed
to generate its proto-grammar in a similar fashion as follows.

|  |
| --- |
| *Term\_product* | | |
|  | | |
|  | *Term\_product*0 : | |
|  |  | SE(*"product"*) *Term\_product*1 |
|  | | |
|  | *Term\_product*1 : | |
|  |  | EE |
|  | | |

The grammar for element particle "product" is created based on [*Term\_product*](#termProduct) given { minOccurs } value of 1 and { maxOccurs } value of *unbounded*. See section [**8.5.4.1.5 Particles**](#particles) for the rules used to generate grammars for particles.

|  |
| --- |
| *Particle\_product*   (before simplification) | | |
|  |

|  |  |  |
| --- | --- | --- |
|  |  |  |
|  | *Term\_product* 0,0 : | |
|  |  | SE("product") *Term\_product* 0,1 |
|  | | |
|  | *Term\_product* 0,1 : | |
|  |  | *Term\_product* 1,0 |
|  | | |
|  | *Term\_product* 1,0 : | |
|  |  | SE("product") *Term\_product* 1,1 |
|  |  | EE |
|  | | |
|  | *Term\_product* 1,1 : | |
|  |  | *Term\_product* 1,0 |
|  | | |

In the above grammars, two grammars *Term\_product* 0,1 and *Term\_product* 1,1 are redundant because they serve for no other purpose than simply relaying one non-terminal to another. Though it is not required, the uses of non-terminals *Term\_product* 0,1 and *Term\_product* 1,1 are each replaced by *Term\_product* 1,0 and *Term\_product* 1,0, which produces the following
simplified
proto-grammars.

|  |
| --- |
|  |

| *Particle\_product*   (after simplification) | | |
| --- | --- | --- |
|  |  | |
|  |  |  |
|  | | |
|  | *Term\_product* 0,0 : | |
|  |  | SE("product") *Term\_product* 1,0 |
|  | | |
|  | *Term\_product* 1,0 : | |
|  |  | SE("product") *Term\_product* 1,0 |
|  |  | EE |
|  | | |

The proto-grammar of the element <order> equates to [*Particle\_product*](#particleProduct) because the type definition of element <order> has no attribute uses, and its content model has both { minOccurs } and { maxOccurs } property values of 1 where the element particle "product" is the sole member of the content model.

|  |
| --- |
|  |

| *ProtoG\_OrderElement* | | |
| --- | --- | --- |
|  |  | |
|  |  |  |
|  | | |
|  | *Term\_product* 0,0 : | |
|  |  | SE("product") *Term\_product* 1,0 |
|  | | |
|  | *Term\_product* 1,0 : | |
|  |  | SE("product") *Term\_product* 1,0 |
|  |  | EE |
|  | | |

### H.2 Normalized Grammar Examples

The element proto-grammars [*ProtoG\_ProductElement*](#protoProductElement) and [*ProtoG\_OrderElement*](#protoOrderElement) produced in the previous section can be turned into their normalized forms which are shown below with an [event code](#key-eventcode) assigned to each production. See section [**8.5.4.2 EXI Normalized Grammars**](#normalizedGrammars) for the process that converts proto-grammars into normalized grammars, and section [**8.5.4.3 Event Code Assignment**](#eventCodeAssignment) for the rules that determine the [event codes](#key-eventcode) of productions in normalized grammars.

|  |
| --- |
|  |

| *NormG\_ProductElement* | | | |
| --- | --- | --- | --- |
|  | | | Event Code |
|  | *Use\_color* 0 : | | |
|  |  | AT("color") [schema-typed value] *Use\_color* 1 | 0 |
|  |  | AT("sku") [schema-typed value] *Use\_sku* 1 | 1 |
|  | | | |
|  | *Use\_color* 1 : | | |
|  |  | AT("sku") [schema-typed value] *Use\_sku* 1 | 0 |
|  | | | |
|  | *Use\_sku* 1 : | | |
|  |  | SE("description") *Term\_description*0,1 | 0 |
|  |  | SE("quantity") *Term\_quantity*0,1 | 1 |
|  | | | |
|  | *Term\_description*0,1 : | | |
|  |  | SE("quantity") *Term\_quantity*0,1 | 0 |
|  | | | |
|  | *Term\_quantity*0,1 : | | |
|  |  | SE("price") *Term\_price*0,1 | 0 |
|  | | | |
|  | *Term\_price*0,1 : | | |
|  |  | SE("description") *Term\_description*1,1 | 0 |
|  |  | SE("quantity") *Term\_quantity*1,1 | 1 |
|  |  | EE | 2 |
|  | | | |
|  | *Term\_description*1,1 : | | |
|  |  | SE("quantity") *Term\_quantity*1,1 | 0 |
|  | | | |
|  | *Term\_quantity*1,1 : | | |
|  |  | SE("price") *Term\_price*1,1 | 0 |
|  | | | |
|  | *Term\_price*1,1 : | | |
|  |  | EE | 0 |
|  | | | |

| *NormG\_OrderElement* | | | |
| --- | --- | --- | --- |
|  | | | Event Code |
|  | *Term\_product* 0,0 : | | |
|  |  | SE("product") *Term\_product* 1,0 | 0 |
|  | | | |
|  | *Term\_product* 1,0: | | |
|  |  | SE("product") *Term\_product* 1,0 | 0 |
|  |  | EE | 1 |
|  | | | |

Note that some
productions
that were present in the proto-grammars have been removed in the normalized grammars.
Those
productions
were culled upon the completion of grammar normalization because their left-hand-side non-terminals are not referenced from right-hand side of any available productions,
and yet those non-terminals are not the first non-terminals of the grammar they belong to.
.

### H.3 Complete Grammar Examples

The normalized grammars [*NormG\_ProductElement*](#normProductElement) and [*NormG\_OrderElement*](#normOrderElement) are augmented with undeclared productions to become complete grammars.
See section [**8.5.4.4 Undeclared Productions**](#undeclaredProductions) for the process
to augment normalized grammars with productions for accepting terminal symbols not declared in schemas.
The complete grammars for elements <product> and <order> are shown below.
Note that the default grammar settings (i.e. the settings that can be described by an empty header options document <exi:header/> is used for the sake of this augmentation process, and those productions that accept ER, NS, CM and PI have been pruned according to the rules described in section [**8.3 Pruning Unneeded Productions**](#pruningProductions) since those
terminal symbols
are not preserved in the default grammar settings.

|  |
| --- |
|  |

| Complete grammar for element <product> | | | |
| --- | --- | --- | --- |
|  | | | Event Code |
|  | *Use\_color* 0 : | | |
|  |  | AT("color") [schema-typed value] *Use\_color* 1 | 0 |
|  |  | AT("sku") [schema-typed value] *Use\_sku* 1 | 1 |
|  |  | EE | 2.0 |
|  |  | AT(xsi:type) *Use\_color* 0 | 2.1 |
|  |  | AT(xsi:nil) *Use\_color* 0 | 2.2 |
|  |  | AT (\*) *Use\_color* 0 | 2.3 |
|  |  | AT("color") [untyped value] *Use\_color*1 | 2.4.0 |
|  |  | AT("sku") [untyped value] *Use\_sku*1 | 2.4.1 |
|  |  | AT (\*) [untyped value] *Use\_color* 0 | 2.4.2 |
|  |  | SE(\*) *Use\_sku* 1\_copied | 2.5 |
|  |  | CH [untyped value] *Use\_sku* 1\_copied | 2.6 |
|  | | | |
|  | *Use\_color* 1 : | | |
|  |  | AT("sku") [schema-typed value] *Use\_sku* 1 | 0 |
|  |  | EE | 1.0 |
|  |  | AT (\*) *Use\_color* 1 | 1.1 |
|  |  | AT("sku") [untyped value] *Use\_sku* 1 | 1.2.0 |
|  |  | AT (\*) [untyped value] *Use\_color* 1 | 1.2.1 |
|  |  | SE(\*) *Use\_sku* 1\_copied | 1.3 |
|  |  | CH [untyped value] *Use\_sku* 1\_copied | 1.4 |
|  | | | |
|  | *Use\_sku* 1 : | | |
|  |  | SE("description") *Term\_description*0,1 | 0 |
|  |  | SE("quantity") *Term\_quantity*0,1 | 1 |
|  |  | EE | 2.0 |
|  |  | AT (\*) *Use\_sku* 1 | 2.1 |
|  |  | AT (\*) [untyped value] *Use\_sku* 1 | 2.2.0 |
|  |  | SE(\*) *Use\_sku* 1\_copied | 2.3 |
|  |  | CH [untyped value] *Use\_sku* 1\_copied | 2.4 |
|  | | | |
|  | *Use\_sku* 1\_copied : | | |
|  |  | SE("description") *Term\_description*0,1 | 0 |
|  |  | SE("quantity") *Term\_quantity*0,1 | 1 |
|  |  | EE | 2.0 |
|  |  | SE(\*) *Use\_sku* 1\_copied | 2.1 |
|  |  | CH [untyped value] *Use\_sku* 1\_copied | 2.2 |
|  | | | |
|  | *Term\_description*0,1 : | | |
|  |  | SE("quantity") *Term\_quantity*0,1 | 0 |
|  |  | EE | 1 |
|  |  | SE(\*) *Term\_description*0,1 | 2.0 |
|  |  | CH [untyped value] *Term\_description*0,1 | 2.1 |
|  | | | |
|  | *Term\_quantity*0,1 : | | |
|  |  | SE("price") *Term\_price*0,1 | 0 |
|  |  | EE | 1 |
|  |  | SE(\*) *Term\_quantity*0,1 | 2.0 |
|  |  | CH [untyped value] *Term\_quantity*0,1 | 2.1 |
|  | | | |
|  | *Term\_price*0,1 : | | |
|  |  | SE("description") *Term\_description*1,1 | 0 |
|  |  | SE("quantity") *Term\_quantity*1,1 | 1 |
|  |  | EE | 2 |
|  |  | SE(\*) *Term\_price*0,1 | 3.0 |
|  |  | CH [untyped value] *Term\_price*0,1 | 3.1 |
|  | | | |
|  | *Term\_description*1,1 : | | |
|  |  | SE("quantity") *Term\_quantity*1,1 | 0 |
|  |  | EE | 1 |
|  |  | SE(\*) *Term\_description*1,1 | 2.0 |
|  |  | CH [untyped value] *Term\_description*1,1 | 2.1 |
|  | | | |
|  | *Term\_quantity*1,1 : | | |
|  |  | SE("price") *Term\_price*1,1 | 0 |
|  |  | EE | 1 |
|  |  | SE(\*) *Term\_quantity*1,1 | 2.0 |
|  |  | CH [untyped value] *Term\_quantity*1,1 | 2.1 |
|  | | | |
|  | *Term\_price*1,1 : | | |
|  |  | EE | 0 |
|  |  | SE(\*) *Term\_price*1,1 | 1.0 |
|  |  | CH [untyped value] *Term\_price*1,1 | 1.1 |
|  | | | |

| Complete grammar for element <order> | | | |
| --- | --- | --- | --- |
|  | | | Event Code |
|  | *Term\_product* 0,0 : | | |
|  |  | SE("product") *Term\_product* 1,0 | 0 |
|  |  | EE | 1.0 |
|  |  | AT(xsi:type) *Term\_product* 0,0 | 1.1 |
|  |  | AT(xsi:nil) *Term\_product* 0,0 | 1.2 |
|  |  | AT (\*) *Term\_product* 0,0 | 1.3 |
|  |  | AT (\*) [untyped value] *Term\_product* 0,0 | 1.4.0 |
|  |  | SE(\*) *Term\_product* 0,0\_copied | 1.5 |
|  |  | CH [untyped value] *Term\_product* 0,0\_copied | 1.6 |
|  | | | |
|  | *Term\_product* 0,0\_copied : | | |
|  |  | SE("product") *Term\_product* 1,0 | 0 |
|  |  | EE | 1.0 |
|  |  | SE(\*) *Term\_product* 0,0\_copied | 1.1 |
|  |  | CH [untyped value] *Term\_product* 0,0\_copied | 1.2 |
|  | | | |
|  | *Term\_product* 1,0 : | | |
|  |  | SE("product") *Term\_product* 1,0 | 0 |
|  |  | EE | 1 |
|  |  | SE(\*) *Term\_product* 1,0 | 2.0 |
|  |  | CH [untyped value] *Term\_product* 1,0 | 2.1 |
|  | | | |

## I Recent Specification Changes (Non-Normative)

### I.1 Changes from First Edition Recommendation

* Clarified the definition and intended use of content index.
  (see [19 August 2013 (1)](https://www.w3.org/XML/EXI/exi-10-errata#clarification20130819a), [19 August 2013 (2)](https://www.w3.org/XML/EXI/exi-10-errata#clarification20130819b),
  [19 August 2013 (3)](https://www.w3.org/XML/EXI/exi-10-errata#clarification20130819c), [19 August 2013 (4)](https://www.w3.org/XML/EXI/exi-10-errata#clarification20130819d),
  [19 August 2013 (5)](https://www.w3.org/XML/EXI/exi-10-errata#clarification20130819e), [19 August 2013 (6)](https://www.w3.org/XML/EXI/exi-10-errata#clarification20130819f))

* Clarified the offset of Integer datatype for bounded range schema types.
  (see [27 June 2013](https://www.w3.org/XML/EXI/exi-10-errata#clarification20130627))

* Add a references to Namespaces in XML 1.1 specification.
  (see [26 June 2013](https://www.w3.org/XML/EXI/exi-10-errata#Substantive20130626))

* Clarified the valid value range of the time components in Date-Time datatype.
  (see [13 June 2013](https://www.w3.org/XML/EXI/exi-10-errata#clarification20130613))

* Clarified that the namespace declarations are mapped to NS events and should not be represented by AT events.
  (see [06 May 2013](https://www.w3.org/XML/EXI/exi-10-errata#clarification20130506))

* Fixed discrepancy between complex type grammars and ur-type grammar.
  (see [29 March 2013 (1)](https://www.w3.org/XML/EXI/exi-10-errata#Substantive20130329a), [29 March 2013 (2)](https://www.w3.org/XML/EXI/exi-10-errata#Substantive20130329b), and [29 March 2013 (3)](https://www.w3.org/XML/EXI/exi-10-errata#Substantive20130329c))

* Clarified that enumerated values do not affect how values of list datatypes are encoded.
  (see [19 September 2012 (1)](https://www.w3.org/XML/EXI/exi-10-errata#Substantive20120919a), [19 September 2012 (2)](https://www.w3.org/XML/EXI/exi-10-errata#Substantive20120919b))

* Clarified that AT(xsi:type) productions are added to a grammar at most once. (see [AT(xsi:type) handling in Built-in Element Grammar](https://www.w3.org/XML/EXI/exi-10-errata#Substantive20120508))

* Improved the wording describing when to add an extra production representing EE when { max\_occurs } is unbounded. (see [Unbounded { max\_occurs } of Particles](https://www.w3.org/XML/EXI/exi-10-errata#clarification20120403))

* Clarified when patterns if any are relevant in Boolean datatype representation. (see [Patterns in Boolean](https://www.w3.org/XML/EXI/exi-10-errata#clarification20120222))

* Clarified how values with enumerated values are represented when a DTRM is in effect. (see [Enumerated Values with DTRM](https://www.w3.org/XML/EXI/exi-10-errata#clarification20111005))

* Added a clarification regarding the restricted character set used for a value that would be represented as an EXI enumeration. (see [Restricted Character Set of Enumeration](https://www.w3.org/XML/EXI/exi-10-errata#clarification20110530))

### I.2 Changes from previous versions of the document

* The changes from First Public Working Draft are available in the [First Edition Recommendation](https://www.w3.org/TR/2011/REC-exi-20110310/#changes)

## J Acknowledgements (Non-Normative)

This document is the work of the [Efficient XML Interchange (EXI) WG](https://www.w3.org/XML/EXI/).

Members of the Working Group are (at the time of writing, sorted alphabetically by last name):

* Carine Bournez, W3C/ERCIM (*staff contact*)
* Don Brutzman, Web3D Consortium
* Michael Cokus, MITRE Corporation
* Yusuke Doi, Toshiba Corporation
* Youenn Fablet, Canon, Inc.
* Jun Fujisawa, Canon, Inc.
* Joerg Heuer, Siemens AG
* Sebastian Käbisch, Siemens AG
* Takuki Kamiya, Fujitsu Laboratories of America, Inc.
  (*chair*)
* Rumen Kyusakov, Invited Expert, Luleå University of Technology
* Richard Kuntschke, Siemens AG
* Don McGregor, Web3D Consortium
* Daniel Peintner, Siemens AG
* Liam Quin, W3C/MIT (*staff contact*)
* Mohamed Zergaoui, INNOVIMAX

The EXI Working Group would like to acknowledge the following former members of the group for their leadership, guidance and expertise they provided throughout their individual tenure in the WG. (sorted in chronologically)

* Oliver Goldman, Adobe Systems, Inc. (*former co-chair*) (until 8 June 2006)
* Robin Berjon, Expway (*former co-chair*) (until 17 October 2006)
* Peter Haggar, IBM (until 7 March 2007)
* Paul Thorpe, OSS Nokalva, Inc. (until 11 Sept 2007)
* Kimmo Raatikainen, Nokia (until 13 March 2008)
* Daniel Vogelheim, Invited Expert (*former co-chair* then from Siemens AG) (until 15 July 2008)
* Stephen Williams, High Performance Technologies, Inc. (until 8 Aug 2008)
* Ed Day, Objective Systems, Inc. (until 23 Oct 2009)
* Santiago Pericas-Geertsen, Sun Microsystems, Inc. (until 6 May 2010)
* Paul Sandoz, Sun Microsystems, Inc. (until 6 May 2010)
* Alan Hudson, Web3D Consortium (until 2 June 2011)
* Sheldon Snyder, Web3D Consortium (until 2 June 2011)
* John Schneider, AgileDelta, Inc. (until 19 July 2012)
* Rich Rollman, AgileDelta, Inc. (until 19 July 2012)
* Nan Ma, China Electronics Standardization Institute (until 19 July 2012)
* Jaakko Kangasharju, University of Helsinki (until 19 July 2012)
* Greg White, Stanford University (*former co-chair*) (until 19 July 2012)
* David Lee, MarkLogic (until 6 September 2013)
* Hideyuki Moribe, Fujitsu Laboratories of America, Inc. (until 14 January 2014)

The EXI working group owes so much to our distinguished colleague from Nokia, Kimmo Raatikainen (1955-2008), on the progress of our work, who succumbed to an ailment on March 13, 2008. His breadth of knowledge, depth of insight, ingenuity and courage to speak up constantly shed a light onto us whenever the group seemed to stray into a futile path of disagreements during the course. We shall never forget and will always appreciate his presence in us, and great contribution that is omnipresent in every aspect of our work throughout.
