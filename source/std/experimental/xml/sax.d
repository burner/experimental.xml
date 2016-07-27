/*
*             Copyright Lodovico Giaretta 2016 - .
*  Distributed under the Boost Software License, Version 1.0.
*      (See accompanying file LICENSE_1_0.txt or copy at
*            http://www.boost.org/LICENSE_1_0.txt)
*/

module std.experimental.xml.sax;

import std.experimental.xml.interfaces;
import std.experimental.xml.cursor;

struct SAXParser(T, alias H)
    if (isCursor!T)
{
    static if (__traits(isTemplate, H))
        alias HandlerType = H!T;
    else
        alias HandlerType = H;
        
    private T cursor;
    public HandlerType handler;
    
    /++
    +   Initializes this parser (and the underlying low level one) with the given input.
    +/
    void setSource(T.InputType input)
    {
        cursor.setSource(input);
    }
    
    static if (isSaveableCursor!T)
    {
        auto save()
        {
            auto result = this;
            result.cursor = cursor.save;
            return result;
        }
    }
    
    /++
    +   Processes the entire document; every time a node of
    +   Kind XXX is found, the corresponding method onXXX(this)
    +   of the handler is called, if it exists.
    +/
    void processDocument()
    {
        import std.traits: hasMember;
        while (!cursor.documentEnd)
        {
            switch (cursor.getKind)
            {
                static if(hasMember!(HandlerType, "onDocument"))
                {
                    case XMLKind.DOCUMENT:
                        handler.onDocument(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onElementStart"))
                {
                    case XMLKind.ELEMENT_START:
                        handler.onElementStart(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onElementEnd"))
                {
                    case XMLKind.ELEMENT_END:
                        handler.onElementEnd(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onElementEmpty"))
                {
                    case XMLKind.ELEMENT_EMPTY:
                        handler.onElementEmpty(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onText"))
                {
                    case XMLKind.TEXT:
                        handler.onText(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onComment"))
                {
                    case XMLKind.COMMENT:
                        handler.onComment(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onProcessingInstruction"))
                {
                    case XMLKind.PROCESSING_INSTRUCTION:
                        handler.onProcessingInstruction(cursor);
                        break;
                }
                static if (hasMember!(HandlerType, "onCDataSection"))
                {
                    case XMLKind.CDATA:
                        handler.onCDataSection(cursor);
                        break;
                }
                default: break;
            }
            
            if (cursor.enter)
            {
            }
            else if (!cursor.next)
                cursor.exit;
        }
    }
}

unittest
{
    import std.experimental.xml.parser;
    import std.experimental.xml.lexers;

    dstring xml = q{
    <?xml encoding = "utf-8" ?>
    <aaa xmlns:myns="something">
        <myns:bbb myns:att='>'>
            <!-- lol -->
            Lots of Text!
            On multiple lines!
        </myns:bbb>
        <![CDATA[ Ciaone! ]]>
        <ccc/>
    </aaa>
    };
    
    struct MyHandler(T)
    {
        int max_nesting;
        int current_nesting;
        int total_invocations;
        
        void onElementStart(ref T node)
        {
            total_invocations++;
            current_nesting++;
            if (current_nesting > max_nesting)
                max_nesting = current_nesting;
        }
        void onElementEnd(ref T node)
        {
            total_invocations++;
            current_nesting--;
        }
        void onElementEmpty(ref T node) { total_invocations++; }
        void onProcessingInstruction(ref T node) { total_invocations++; }
        void onText(ref T node) { total_invocations++; }
        void onDocument(ref T node)
        {
            auto attrs = node.getAttributes;
            assert(attrs.front == Attribute!dstring("encoding", "utf-8"));
            attrs.popFront;
            assert(attrs.empty);
            total_invocations++;
        }
        void onComment(ref T node)
        {
            assert(node.getContent == " lol ");
            total_invocations++;
        }
    }
    
    auto parser = SAXParser!(Cursor!(Parser!(SliceLexer!dstring)), MyHandler)();
    parser.setSource(xml);
    
    parser.processDocument();
    
    assert(parser.handler.max_nesting == 2);
    assert(parser.handler.current_nesting == 0);
    assert(parser.handler.total_invocations == 9);
}
