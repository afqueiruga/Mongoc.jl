
#
# Types
#

# BSONType mirrors C enum bson_type_t.
primitive type BSONType 8 end # 1 byte

Base.convert(::Type{T}, t::BSONType) where {T<:Number} = reinterpret(UInt8, t)
Base.convert(::Type{BSONType}, n::T) where {T<:Number} = reinterpret(BSONType, n)
BSONType(u::UInt8) = convert(BSONType, u)

#
# Constants for BSONType
#

const BSON_TYPE_EOD        = BSONType(0x00)
const BSON_TYPE_DOUBLE     = BSONType(0x01)
const BSON_TYPE_UTF8       = BSONType(0x02)
const BSON_TYPE_DOCUMENT   = BSONType(0x03)
const BSON_TYPE_ARRAY      = BSONType(0x04)
const BSON_TYPE_BINARY     = BSONType(0x05)
const BSON_TYPE_UNDEFINED  = BSONType(0x06)
const BSON_TYPE_OID        = BSONType(0x07)
const BSON_TYPE_BOOL       = BSONType(0x08)
const BSON_TYPE_DATE_TIME  = BSONType(0x09)
const BSON_TYPE_NULL       = BSONType(0x0A)
const BSON_TYPE_REGEX      = BSONType(0x0B)
const BSON_TYPE_DBPOINTER  = BSONType(0x0C)
const BSON_TYPE_CODE       = BSONType(0x0D)
const BSON_TYPE_SYMBOL     = BSONType(0x0E)
const BSON_TYPE_CODEWSCOPE = BSONType(0x0F)
const BSON_TYPE_INT32      = BSONType(0x10)
const BSON_TYPE_TIMESTAMP  = BSONType(0x11)
const BSON_TYPE_INT64      = BSONType(0x12)
const BSON_TYPE_DECIMAL128 = BSONType(0x13)
const BSON_TYPE_MAXKEY     = BSONType(0x7F)
const BSON_TYPE_MINKEY     = BSONType(0xFF)



# BSONSubType mirrors C enum bson_subtype_t.
primitive type BSONSubType 8 end

Base.convert(::Type{T}, t::BSONSubType) where {T<:Number} = reinterpret(UInt8, t)
Base.convert(::Type{BSONSubType}, n::T) where {T<:Number} = reinterpret(BSONSubType, n)
BSONSubType(u::UInt8) = convert(BSONSubType, u)

#
# Constants for BSONSubType
#

const BSON_SUBTYPE_BINARY            = BSONSubType(0x00)
const BSON_SUBTYPE_FUNCTION          = BSONSubType(0x01)
const BSON_SUBTYPE_BINARY_DEPRECATED = BSONSubType(0x02)
const BSON_SUBTYPE_UUID_DEPRECATED   = BSONSubType(0x03)
const BSON_SUBTYPE_UUID              = BSONSubType(0x04)
const BSON_SUBTYPE_MD5               = BSONSubType(0x05)
const BSON_SUBTYPE_USER              = BSONSubType(0x80)

#=
BSONIter mirrors C struct bson_iter_t and can be allocated in the stack.

According to [libbson documentation](http://mongoc.org/libbson/current/bson_iter_t.html),
it is meant to be used on the stack and can be discarded at any time
as it contains no external allocation.
The contents of the structure should be considered private
and may change between releases, however the structure size will not change.

Inspecting its size in C, we get:

```c
sizeof(bson_iter_t) == 80
```
=#
primitive type BSONIter 80 * 8 end # 80 bytes

"""
A `BSONObjectId` represents a unique identifier
for a BSON document.

# Example

The following generates a new `BSONObjectId`.

```julia
julia> Mongoc.BSONObjectId()
```

# C API

`BSONObjectId` instances addresses are passed
to libbson/libmongoc API using `Ref(oid)`,
and are owned by the Julia process.

Mirrors C struct `bson_oid_t`:

```c
typedef struct {
   uint8_t bytes[12];
} bson_oid_t;
```
"""
struct BSONObjectId
    bytes::NTuple{12, UInt8}
end

function BSONObjectId()
    oid_ref = Ref{BSONObjectId}()
    bson_oid_init(oid_ref, C_NULL)
    return oid_ref[]
end

function BSONObjectId(oid_string::String)
    if !bson_oid_is_valid(oid_string)
        error("'$oid_string' is not a valid ObjectId.")
    end
    oid_ref = Ref{BSONObjectId}()
    bson_oid_init_from_string(oid_ref, oid_string)
    return oid_ref[]
end

function BSONObjectId(oid::BSONObjectId)
    return BSONObjectId(oid.bytes)
end

Base.copy(oid::BSONObjectId) = BSONObjectId(oid)

"""
`BSONError` is the default `Exception`
for BSON/MongoDB function call errors.

# C API

Mirrors C struct `bson_error_t`.

`BSONError` instances addresses are passed
to libbson/libmongoc API using `Ref(error)`,
and are owned by the Julia process.

```c
typedef struct {
   uint32_t domain;
   uint32_t code;
   char message[504];
} bson_error_t;
```
"""
struct BSONError <: Exception
    domain::UInt32
    code::UInt32
    message::NTuple{504, UInt8}
end

"""
`BSONCode` is a BSON element
with JavaScript source code.

# Example

```julia
julia> bson = Mongoc.BSON("source" => Mongoc.BSONCode("function() = 1"))
BSON("{ "source" : { "\$code" : "function() = 1" } }")
```
"""
struct BSONCode
    code::String
end

"""
A `BSON` represents a document in *Binary JSON* format,
defined at http://bsonspec.org/.

In Julia, you can manipulate a `BSON` instance
just like a `Dict`.

# Example

```julia
bson = Mongoc.BSON()
bson["name"] = "my name"
bson["num"] = 10.0
```

# C API

`BSON` is a wrapper for C struct `bson_t`.
"""
mutable struct BSON
    handle::Ptr{Cvoid}

    function BSON(handle::Ptr{Cvoid}; enable_finalizer::Bool=true)
        new_bson = new(handle)
        if enable_finalizer
            finalizer(destroy!, new_bson)
        end
        return new_bson
    end
end

function destroy!(bson::BSON)
    if bson.handle != C_NULL
        bson_destroy(bson.handle)
        bson.handle = C_NULL
    end
    nothing
end

function Base.deepcopy(bson::BSON) :: BSON
    return BSON(bson_copy(bson.handle))
end

mutable struct BSONReader
    handle::Ptr{Cvoid}
    data::Vector{UInt8}

    function BSONReader(handle::Ptr{Cvoid}, data::Vector{UInt8})
        new_reader = new(handle, data)
        finalizer(destroy!, new_reader)
        return new_reader
    end
end

function destroy!(reader::BSONReader)
    if reader.handle != C_NULL
        bson_reader_destroy(reader.handle)
        reader.handle = C_NULL
    end
    nothing
end

const DEFAULT_BSON_WRITER_BUFFER_CAPACITY = 2^10

# buffer_handle must be a valid pointer to a Buffer object.
# A reference to this buffer must be kept from outside this function
# to avoid GC on it.
function unsafe_buffer_realloc(buffer_ptr::Ptr{UInt8}, num_bytes::Csize_t, writer_objref::Ptr{Cvoid})
    local writer::BSONWriter = unsafe_pointer_to_objref(writer_objref)
    @assert buffer_ptr == pointer(writer.buffer) "Is this the same BSONWriter?"

    current_len = length(writer.buffer)
    inc = num_bytes - current_len
    if inc > 0
        append!(writer.buffer, [ UInt8(0) for i in 1:inc ])
    end

    @assert length(writer.buffer) == num_bytes
    writer.buffer_length_ref[] = num_bytes

    return pointer(writer.buffer)
end

mutable struct BSONWriter
    handle::Ptr{Cvoid}
    buffer::Vector{UInt8}
    buffer_handle_ref::Ref{Ptr{UInt8}}
    buffer_length_ref::Ref{Csize_t}

    function BSONWriter(initial_buffer_capacity::Integer=DEFAULT_BSON_WRITER_BUFFER_CAPACITY,
                        buffer_offset::Integer=0)

        buffer = zeros(UInt8, initial_buffer_capacity)
        new_writer = new(C_NULL, buffer, Ref(pointer(buffer)), Ref(Csize_t(initial_buffer_capacity)))
        finalizer(destroy!, new_writer)

        realloc_func = @cfunction(unsafe_buffer_realloc, Ptr{UInt8}, (Ptr{UInt8}, Csize_t, Ptr{Cvoid}))

        handle = bson_writer_new(new_writer.buffer_handle_ref,
                                 new_writer.buffer_length_ref,
                                 Csize_t(buffer_offset),
                                 realloc_func,
                                 pointer_from_objref(new_writer))
        if handle == C_NULL
            error("Failed to create a BSONWriter.")
        end
        new_writer.handle = handle

        return new_writer
    end
end

function destroy!(writer::BSONWriter)
    if writer.handle != C_NULL
        bson_writer_destroy(writer.handle)
        writer.handle = C_NULL
    end
    nothing
end

#
# API
#

Base.convert(::Type{String}, oid::BSONObjectId) = bson_oid_to_string(oid)
Base.string(oid::BSONObjectId) = convert(String, oid)
Base.convert(::Type{BSONObjectId}, oid_string::String) = BSONObjectId(oid_string)

Base.convert(::Type{String}, code::BSONCode) = code.code
Base.string(code::BSONCode) = convert(String, code)
Base.convert(::Type{BSONCode}, code_string::String) = BSONCode(code_string)

Base.show(io::IO, oid::BSONObjectId) = print(io, "BSONObjectId(\"", string(oid), "\")")
Base.show(io::IO, bson::BSON) = print(io, "BSON(\"", as_json(bson), "\")")
Base.show(io::IO, code::BSONCode) = print(io::IO, "BSONCode(\"$(code.code)\")")

function Base.showerror(io::IO, err::BSONError)
    for c in err.message
        c_char = Char(c)
        if c_char == '\0'
            break
        else
            print(io, c_char)
        end
    end
end

function get_time(oid::BSONObjectId)
    return Dates.unix2datetime(bson_oid_get_time_t(oid))
end

function BSON()
    handle = bson_new()
    if handle == C_NULL
        error("Failed to create a new BSON document.")
    end
    return BSON(handle)
end

function BSON(json_string::String)
    handle = bson_new_from_json(json_string)
    if handle == C_NULL
        error("Failed parsing JSON to BSON. $json_string.")
    end
    return BSON(handle)
end

function BSON(vector::Vector)
    result = BSON()

    for (i, v) in enumerate(vector)
        result[string(i-1)] = v
    end

    return result
end

function BSON(args::Pair...)
    result = BSON()

    for (k, v) in args
        result[k] = v
    end

    return result
end

BSON(dict::Dict) = BSON(dict...)

"""
    as_json(bson::BSON; canonical::Bool=false) :: String

Converts a `bson` object to a JSON string.

# Example

```julia
julia> document = Mongoc.BSON("{ \"hey\" : 1 }")
BSON("{ "hey" : 1 }")

julia> Mongoc.as_json(document)
"{ \"hey\" : 1 }"

julia> Mongoc.as_json(document, canonical=true)
"{ \"hey\" : { \"\$numberInt\" : \"1\" } }"
```

# C API

* [`bson_as_canonical_extended_json`](http://mongoc.org/libbson/current/bson_as_canonical_extended_json.html)

* [`bson_as_relaxed_extended_json`](http://mongoc.org/libbson/current/bson_as_relaxed_extended_json.html)
"""
function as_json(bson::BSON; canonical::Bool=false) :: String
    local bson_cstring::Cstring

    if canonical
        bson_cstring = bson_as_canonical_extended_json(bson.handle)
    else
        bson_cstring = bson_as_relaxed_extended_json(bson.handle)
    end

    if bson_cstring == C_NULL
        error("Couldn't convert bson to json.")
    end

    result = unsafe_string(bson_cstring)
    bson_free(convert(Ptr{Cvoid}, bson_cstring))

    return result
end

#
# Read values from BSON
#

has_field(bson::BSON, key::String) = bson_has_field(bson.handle, key)
Base.haskey(bson::BSON, key::String) = has_field(bson, key)

function bson_iter_init(document::BSON) :: Ref{BSONIter}
    iter_ref = Ref{BSONIter}()
    ok = bson_iter_init(iter_ref, document.handle)
    if !ok
        error("Couldn't create iterator for BSON document.")
    end
    return iter_ref
end

struct BSONIterator
    bson_iter_ref::Ref{BSONIter}
    document::BSON

    function BSONIterator(document::BSON)
        iter_ref = bson_iter_init(document)
        return new(iter_ref, document)
    end
end

function Base.iterate(document::BSON)
    itr = BSONIterator(document)
    iterate(document, itr)
end

function Base.iterate(document::BSON, state::BSONIterator)

    if bson_iter_next(state.bson_iter_ref)
        key = unsafe_string(bson_iter_key(state.bson_iter_ref))
        value = get_value(state.bson_iter_ref)

        return key => value, state
    end

    return nothing
end

"""
    as_dict(document::BSON) :: Dict

Converts a BSON document to a Julia `Dict`.
"""
function as_dict(document::BSON) :: Dict
    result = Dict()
    for (k, v) in document
        result[k] = v
    end
    return result
end

function as_dict(iter_ref::Ref{BSONIter}) :: Dict
    result = Dict()
    while bson_iter_next(iter_ref)
        result[unsafe_string(bson_iter_key(iter_ref))] = get_value(iter_ref)
    end
    return result
end

function get_value(iter_ref::Ref{BSONIter})
    local bson_type::BSONType = bson_iter_type(iter_ref)

    if bson_type == BSON_TYPE_UTF8
        return unsafe_string(bson_iter_utf8(iter_ref))
    elseif bson_type == BSON_TYPE_INT64
        return bson_iter_int64(iter_ref)
    elseif bson_type == BSON_TYPE_INT32
        return bson_iter_int32(iter_ref)
    elseif bson_type == BSON_TYPE_DOUBLE
        return bson_iter_double(iter_ref)
    elseif bson_type == BSON_TYPE_OID
        # converts Ptr{BSONObjectId} to BSONObjectId
        return unsafe_load(bson_iter_oid(iter_ref))
    elseif bson_type == BSON_TYPE_BOOL
        return bson_iter_bool(iter_ref)
    elseif bson_type == BSON_TYPE_DATE_TIME
        millis = Int64(bson_iter_date_time(iter_ref))
        return isodate2datetime(millis)

    elseif bson_type == BSON_TYPE_ARRAY || bson_type == BSON_TYPE_DOCUMENT

        child_iter_ref = Ref{BSONIter}()
        ok = bson_iter_recurse(iter_ref, child_iter_ref)
        if !ok
            error("Couldn't iterate array inside BSON.")
        end

        if bson_type == BSON_TYPE_ARRAY
            result_vector = Vector()
            while bson_iter_next(child_iter_ref)
                push!(result_vector, get_value(child_iter_ref))
            end
            return result_vector
        else
            @assert bson_type == BSON_TYPE_DOCUMENT
            return as_dict(child_iter_ref)
        end
    elseif bson_type == BSON_TYPE_BINARY

        length_ref = Ref{UInt32}()
        buffer_ref = Ref{Ptr{UInt8}}()
        bson_iter_binary(iter_ref, length_ref, buffer_ref)

        result_data = Vector{UInt8}(undef, length_ref[])
        unsafe_copyto!(pointer(result_data), buffer_ref[], length_ref[])

        return result_data

    elseif bson_type == BSON_TYPE_CODE
        return BSONCode(unsafe_string(bson_iter_code(iter_ref)))
    elseif bson_type == BSON_TYPE_NULL
        return nothing
    else
        error("BSON Type not supported: $bson_type.")
    end
end

function Base.getindex(document::Mongoc.BSON, key::String)
    iter_ref = Ref{BSONIter}()
    ok = bson_iter_init_find(iter_ref, document.handle, key)
    if !ok
        error("Key $key not found.")
    end
    return get_value(iter_ref)
end

#
# Write values to BSON
#

function Base.setindex!(document::BSON, value::BSONObjectId, key::String)
    ok = bson_append_oid(document.handle, key, -1, value)
    if !ok
        error("Couldn't append oid to BSON document.")
    end
    nothing
end

function Base.setindex!(document::BSON, value::Int64, key::String)
    ok = bson_append_int64(document.handle, key, -1, value)
    if !ok
        error("Couldn't append Int64 to BSON document.")
    end
    nothing
end

function Base.setindex!(document::BSON, value::Int32, key::String)
    ok = bson_append_int32(document.handle, key, -1, value)
    if !ok
        error("Couldn't append Int32 to BSON document.")
    end
    nothing
end

function Base.setindex!(document::BSON, value::AbstractString, key::String)
    ok = bson_append_utf8(document.handle, key, -1, value, -1)
    if !ok
        error("Couldn't append String to BSON document.")
    end
    nothing
end

function Base.setindex!(document::BSON, value::Bool, key::String)
    ok = bson_append_bool(document.handle, key, -1, value)
    if !ok
        error("Couldn't append Bool to BSON document.")
    end
    nothing
end

function Base.setindex!(document::BSON, value::Float64, key::String)
    ok = bson_append_double(document.handle, key, -1, value)
    if !ok
        error("Couldn't append Float64 to BSON document.")
    end
    nothing
end

function Base.setindex!(document::BSON, value::DateTime, key::String)
    ok = bson_append_date_time(document.handle, key, -1, datetime2isodate(value))
    if !ok
        error("Couldn't append DateTime to BSON document.")
    end
    nothing
end

function Base.setindex!(document::BSON, value::BSON, key::String)
    ok = bson_append_document(document.handle, key, -1, value.handle)
    if !ok
        error("Couldn't append Sub-Document BSON to BSON document.")
    end
    nothing
end

Base.setindex!(document::BSON, value::Dict, key::String) = setindex!(document, BSON(value), key)

function Base.setindex!(document::BSON, value::Vector{T}, key::String) where T
    sub_document = BSON(value)
    ok = bson_append_array(document.handle, key, -1, sub_document.handle)
    if !ok
        error("Couldn't append array to BSON document.")
    end
    nothing
end

function Base.setindex!(document::BSON, value::BSONCode, key::String)
    ok = bson_append_code(document.handle, key, -1, value.code)
    if !ok
        error("Couldn't append String to BSON document.")
    end
    nothing
end

function Base.setindex!(document::BSON, value::Date, key::String)
    error("BSON format does not support `Date` type. Use `DateTime` instead.")
end

function Base.setindex!(document::BSON, value::Vector{UInt8}, key::String)
  ok = bson_append_binary(document.handle, key, -1, BSON_SUBTYPE_BINARY, value, UInt32(length(value)))
  if !ok
      error("Couldn't append array to BSON document.")
  end
  nothing
end

function Base.setindex!(document::BSON, ::Nothing, key::String)
    ok = bson_append_null(document.handle, key, -1)
    if !ok
        error("Couldn't append missing value to BSON document.")
    end
    nothing
end

#
# Write/Read BSON to/from IO
#

function _get_number_of_bytes_written_to_buffer(buffer::Vector{UInt8}) :: Int64
    isempty(buffer) && return 0

    # the first 4 bytes in data is a size int32
    doc_size = reinterpret(Int32, buffer[1:4])[1]
    local total_size::Int64 = 0
    while doc_size != 0
        total_size += doc_size

        if length(buffer) < total_size + 4
            break
        end

        doc_size = reinterpret(Int32, buffer[total_size+1:total_size+4])[1]
    end
    return total_size
end

function _get_number_of_bytes_written_to_buffer(writer::BSONWriter)
    _get_number_of_bytes_written_to_buffer(writer.buffer)
end

function bson_writer(f::Function, io::IO;
                     initial_buffer_capacity::Integer=DEFAULT_BSON_WRITER_BUFFER_CAPACITY)

    writer = BSONWriter(initial_buffer_capacity)

    try
        f(writer)

        @assert bson_writer_get_length(writer.handle) == _get_number_of_bytes_written_to_buffer(writer)

        for byte_index in 1:bson_writer_get_length(writer.handle)
            write(io, writer.buffer[byte_index])
        end

        flush(io)
    finally
        destroy!(writer)
    end

    nothing
end

function write_bson(f::Function, writer::BSONWriter)
    bson_handle_ref = Ref{Ptr{Cvoid}}(C_NULL)
    ok = bson_writer_begin(writer.handle, bson_handle_ref)
    if !ok
        error("Failed to write bson document to IO: there was not enough space in buffer. Increase the buffer initial capacity.")
    end

    bson = BSON(bson_handle_ref[], enable_finalizer=false)
    f(bson)
    bson_writer_end(writer.handle)
end

"""
    write_bson(io::IO, bson::BSON;
        initial_buffer_capacity::Integer=DEFAULT_BSON_WRITER_BUFFER_CAPACITY)

Writes a single BSON document to `io` in binary format.
"""
function write_bson(io::IO, bson::BSON;
                    initial_buffer_capacity::Integer=DEFAULT_BSON_WRITER_BUFFER_CAPACITY)

    bson_writer(io, initial_buffer_capacity=initial_buffer_capacity) do writer
        write_bson(writer) do dest
            bson_copy_to_excluding_noinit(bson.handle, dest.handle)
        end
    end

    nothing
end

"""
    write_bson(io::IO, bson_list::Vector{BSON};
        initial_buffer_capacity::Integer=DEFAULT_BSON_WRITER_BUFFER_CAPACITY)

Writes a vector of BSON documents to `io` in binary format.

# Example

```julia
list = Vector{Mongoc.BSON}()

let
    src = Mongoc.BSON()
    src["id"] = 1
    src["name"] = "1st"
    push!(list, src)
end

let
    src = Mongoc.BSON()
    src["id"] = 2
    src["name"] = "2nd"
    push!(list, src)
end

open("documents.bson", "w") do io
    Mongoc.write_bson(io, list)
end
```
"""
function write_bson(io::IO, bson_list::Vector{BSON};
                    initial_buffer_capacity::Integer=DEFAULT_BSON_WRITER_BUFFER_CAPACITY)

    bson_writer(io, initial_buffer_capacity=initial_buffer_capacity) do writer
        for src_bson in bson_list
            write_bson(writer) do dest
                bson_copy_to_excluding_noinit(src_bson.handle, dest.handle)
            end
        end
    end

    nothing
end

"""
    read_bson(io::IO) :: Vector{BSON}

Reads all BSON documents from `io`.
This method will continue to read from `io` until
it reaches eof.
"""
read_bson(io::IO) :: Vector{BSON} = read_bson(read(io))

"""
    read_bson(data::Vector{UInt8}) :: Vector{BSON}

Parses a vector of bytes to a vector of BSON documents.
Useful when reading BSON as binary from a stream.
"""
function read_bson(data::Vector{UInt8}) :: Vector{BSON}
    if isempty(data)
        return result
    end

    data_shrinked = data[1:_get_number_of_bytes_written_to_buffer(data)]

    reader_handle = bson_reader_new_from_data(pointer(data_shrinked), length(data_shrinked))
    if reader_handle == C_NULL
        error("Failed to create a BSONReader.")
    end
    reader = BSONReader(reader_handle, data_shrinked)
    return read_bson(reader)
end

"""
    read_bson(filepath::AbstractString) :: Vector{BSON}

Reads all BSON documents from a file located at `filepath`.

This will open a `Mongoc.BSONReader` pointing to the file
and will parse file contents to BSON documents.
"""
function read_bson(filepath::AbstractString) :: Vector{BSON}
    @assert isfile(filepath) "$filepath not found."
    err_ref = Ref{BSONError}()
    reader_handle = bson_reader_new_from_file(filepath, err_ref)
    if reader_handle == C_NULL
        throw(err_ref[])
    end
    reader = BSONReader(reader_handle, Vector{UInt8}())
    return read_bson(reader)
end

"""
    read_bson(reader::BSONReader) :: Vector{BSON}

Reads all BSON documents from a `reader`.
"""
function read_bson(reader::BSONReader) :: Vector{BSON}
    result = Vector{BSON}()
    bson = read_next_bson(reader)
    while bson != nothing
        push!(result, bson)
        bson = read_next_bson(reader)
    end
    return result
end

"""
    read_next_bson(reader::BSONReader) :: Union{Nothing, BSON}

Reads the next BSON document available in the stream pointed by `reader`.
Returns `nothing` if reached the end of the stream.
"""
function read_next_bson(reader::BSONReader) :: Union{Nothing, BSON}
    reached_eof_ref = Ref(false)
    bson_handle = bson_reader_read(reader.handle, reached_eof_ref)

    if bson_handle == C_NULL
        if !reached_eof_ref[]
            @warn("Finished reading BSON from stream, but didn't reach stream's eof.")
        end
        return nothing
    end

    bson_copy_handle = bson_copy(bson_handle) # creates a copy with its own lifetime
    return BSON(bson_copy_handle)
end
