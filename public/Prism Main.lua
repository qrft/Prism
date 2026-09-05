if not getgenv().PrismLoaded then
    return
end

getgenv().PrismMain = {
    Svc = {
        Players = game:GetService("Players"),
        TweenService = game:GetService("TweenService"),
        RunService = game:GetService("RunService"),
        CoreGui = game:GetService("CoreGui"),
    },
    UI = {},
}

local PM = getgenv().PrismMain
local LP = PM.Svc.Players.LocalPlayer


local HttpService = game:GetService("HttpService")

-- PNG Decoder Library
local function DecodePng(PngData: buffer)
	--!optimize 2
	--!native
	--!strict

	type InflateHuffman = {
		Lookup: buffer,
	}

	type DecodedPng = {
		Animated: boolean,
		Size: Vector2,
		RGBA8: buffer,
		Frame: buffer,
		AdvanceFrame: () -> (),
		Reset: () -> (),
		Finished: boolean,
		Delay: number,
	}

	type PngFrame = {
		Width: number,
		Height: number,
		XOffset: number,
		YOffset: number,
		DelayNumerator: number,
		DelayDenominator: number,
		DisposeOp: number,
		BlendOp: number,
		DataOffsets: { [number]: number },
		DataLengths: { [number]: number },
		DataLength: number,
		DataFromIdat: boolean,
		Pixels: buffer,
	}

	type PngState = {
		Width: number,
		Height: number,
		Frames: { PngFrame },
		PlayCount: number,
		CompletedPlays: number,
		Canvas: buffer,
		CurrentFrameIndex: number,
		RestoreBuffer: buffer?,
		RestoreX: number,
		RestoreY: number,
		RestoreWidth: number,
		RestoreHeight: number,
		Result: DecodedPng?,
	}

	local EmptyInflateData = buffer.create(0)
	local MaxLookupBits = 15
	local HuffmanLookupSize = 32768
	local AdlerBase = 65521
	local MaxMetadataInflateBytes = 16777216

	local PngSignature0 = 0x89
	local PngSignature1 = 0x50
	local PngSignature2 = 0x4e
	local PngSignature3 = 0x47
	local PngSignature4 = 0x0d
	local PngSignature5 = 0x0a
	local PngSignature6 = 0x1a
	local PngSignature7 = 0x0a

	local ChunkIHDR = 0x49484452
	local ChunkPLTE = 0x504c5445
	local ChunkIDAT = 0x49444154
	local ChunkIEND = 0x49454e44
	local ChunkTRNS = 0x74524e53
	local ChunkACTL = 0x6163544c
	local ChunkFCTL = 0x6663544c
	local ChunkFDAT = 0x66644154
	local ChunkSRGB = 0x73524742
	local ChunkGAMA = 0x67414d41
	local ChunkCHRM = 0x6348524d
	local ChunkICCP = 0x69434350
	local ChunkSBIT = 0x73424954
	local ChunkBKGD = 0x624b4744
	local ChunkPHYS = 0x70485973
	local ChunkHIST = 0x68495354
	local ChunkTIME = 0x74494d45
	local ChunkTEXT = 0x74455874
	local ChunkZTXT = 0x7a545874
	local ChunkITXT = 0x69545874
	local ChunkCICP = 0x63494350
	local ChunkEXIF = 0x65584966
	local ChunkSPLT = 0x73504c54
	local ChunkOFFS = 0x6f464673
	local ChunkGIFG = 0x67494667
	local ChunkGIFX = 0x67494678
	local ChunkSTER = 0x73544552

	local MaxOutputBytes = 2147483647

	local Adam7StartX = {0, 4, 0, 2, 0, 1, 0}
	local Adam7StartY = {0, 0, 4, 0, 2, 0, 1}
	local Adam7StepX = {8, 8, 4, 4, 2, 2, 1}
	local Adam7StepY = {8, 8, 8, 4, 4, 2, 2}
	local CodeLengthOrder = {16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15}
	local LengthBase = {3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31, 35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258}
	local LengthExtra = {0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0}
	local DistanceBase = {1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193, 257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145, 8193, 12289, 16385, 24577}
	local DistanceExtra = {0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13}

	local BitPowers = {}
	for i = 0, 32 do
		BitPowers[i] = 2 ^ i
	end

	local CrcTable = buffer.create(1024)
	local CrcTable1 = buffer.create(1024)
	local CrcTable2 = buffer.create(1024)
	local CrcTable3 = buffer.create(1024)
	local CrcTable4 = buffer.create(1024)
	local CrcTable5 = buffer.create(1024)
	local CrcTable6 = buffer.create(1024)
	local CrcTable7 = buffer.create(1024)

	for Index = 0, 255 do
		local Crc = Index
		for _ = 1, 8 do
			if bit32.btest(Crc, 1) then
				Crc = bit32.bxor(bit32.rshift(Crc, 1), 0xedb88320)
			else
				Crc = bit32.rshift(Crc, 1)
			end
		end
		buffer.writeu32(CrcTable, Index * 4, Crc)
	end

	for Index = 0, 255 do
		local Crc = buffer.readu32(CrcTable, Index * 4)
		Crc = bit32.bxor(bit32.rshift(Crc, 8), buffer.readu32(CrcTable, bit32.band(Crc, 0xff) * 4))
		buffer.writeu32(CrcTable1, Index * 4, Crc)
		Crc = bit32.bxor(bit32.rshift(Crc, 8), buffer.readu32(CrcTable, bit32.band(Crc, 0xff) * 4))
		buffer.writeu32(CrcTable2, Index * 4, Crc)
		Crc = bit32.bxor(bit32.rshift(Crc, 8), buffer.readu32(CrcTable, bit32.band(Crc, 0xff) * 4))
		buffer.writeu32(CrcTable3, Index * 4, Crc)
		Crc = bit32.bxor(bit32.rshift(Crc, 8), buffer.readu32(CrcTable, bit32.band(Crc, 0xff) * 4))
		buffer.writeu32(CrcTable4, Index * 4, Crc)
		Crc = bit32.bxor(bit32.rshift(Crc, 8), buffer.readu32(CrcTable, bit32.band(Crc, 0xff) * 4))
		buffer.writeu32(CrcTable5, Index * 4, Crc)
		Crc = bit32.bxor(bit32.rshift(Crc, 8), buffer.readu32(CrcTable, bit32.band(Crc, 0xff) * 4))
		buffer.writeu32(CrcTable6, Index * 4, Crc)
		Crc = bit32.bxor(bit32.rshift(Crc, 8), buffer.readu32(CrcTable, bit32.band(Crc, 0xff) * 4))
		buffer.writeu32(CrcTable7, Index * 4, Crc)
	end

	local InflateData = EmptyInflateData
	local InflateLength = 0
	local InflatePos = 0
	local InflateBits = 0
	local InflateBitCount = 0
	local InflateOutput = EmptyInflateData
	local InflateOutputPos = 0
	local InflateOutputLength = 0

	local FixedLiteralLengths = buffer.create(288)
	local FixedDistanceLengths = buffer.create(32)

	for Symbol = 0, 143 do
		buffer.writeu8(FixedLiteralLengths, Symbol, 8)
	end
	for Symbol = 144, 255 do
		buffer.writeu8(FixedLiteralLengths, Symbol, 9)
	end
	for Symbol = 256, 279 do
		buffer.writeu8(FixedLiteralLengths, Symbol, 7)
	end
	for Symbol = 280, 287 do
		buffer.writeu8(FixedLiteralLengths, Symbol, 8)
	end
	for Symbol = 0, 31 do
		buffer.writeu8(FixedDistanceLengths, Symbol, 5)
	end

	local function ReadU32BE(Data: buffer, Offset: number): number
		return bit32.byteswap(buffer.readu32(Data, Offset))
	end

	local function ReadU16BE(Data: buffer, Offset: number): number
		return bit32.rshift(bit32.byteswap(buffer.readu16(Data, Offset)), 16)
	end

	local function SliceBuffer(Data: buffer, Offset: number, Count: number): buffer
		local Result = buffer.create(Count)
		buffer.copy(Result, 0, Data, Offset, Count)
		return Result
	end

	local function IsChunkNameByte(Value: number): boolean
		return (Value >= 0x41 and Value <= 0x5a) or (Value >= 0x61 and Value <= 0x7a)
	end

	local function ValidateChunkName(Data: buffer, Offset: number)
		local Byte0 = buffer.readu8(Data, Offset)
		local Byte1 = buffer.readu8(Data, Offset + 1)
		local Byte2 = buffer.readu8(Data, Offset + 2)
		local Byte3 = buffer.readu8(Data, Offset + 3)
		if not IsChunkNameByte(Byte0) or not IsChunkNameByte(Byte1) or not IsChunkNameByte(Byte2) or not IsChunkNameByte(Byte3) then
			error("invalid PNG chunk name")
		end
		if bit32.btest(Byte2, 32) then
			error("invalid PNG chunk reserved bit")
		end
	end

	local function IsCriticalChunk(Data: buffer, Offset: number): boolean
		return bit32.band(buffer.readu8(Data, Offset), 32) == 0
	end

	local function Crc32(Data: buffer, TypeOffset: number, DataOffset: number, DataLength: number): number
		local Lookup = CrcTable
		local Lookup1 = CrcTable1
		local Lookup2 = CrcTable2
		local Lookup3 = CrcTable3
		local Lookup4 = CrcTable4
		local Lookup5 = CrcTable5
		local Lookup6 = CrcTable6
		local Lookup7 = CrcTable7
		local Crc = 0xffffffff
		local DataEnd = DataOffset + DataLength
		local TotalLength = DataLength + 4
		local DataBlockEnd8 = DataEnd - bit32.band(TotalLength, 7)
		local Offset = TypeOffset
		while Offset < DataBlockEnd8 do
			local Word0 = bit32.bxor(Crc, buffer.readu32(Data, Offset))
			local Word1 = buffer.readu32(Data, Offset + 4)
			Crc = bit32.bxor(
				buffer.readu32(Lookup7, bit32.band(Word0, 0xff) * 4),
				buffer.readu32(Lookup6, bit32.band(bit32.rshift(Word0, 8), 0xff) * 4),
				buffer.readu32(Lookup5, bit32.band(bit32.rshift(Word0, 16), 0xff) * 4),
				buffer.readu32(Lookup4, bit32.rshift(Word0, 24) * 4),
				buffer.readu32(Lookup3, bit32.band(Word1, 0xff) * 4),
				buffer.readu32(Lookup2, bit32.band(bit32.rshift(Word1, 8), 0xff) * 4),
				buffer.readu32(Lookup1, bit32.band(bit32.rshift(Word1, 16), 0xff) * 4),
				buffer.readu32(Lookup, bit32.rshift(Word1, 24) * 4)
			)
			Offset = Offset + 8
		end
		if Offset + 4 <= DataEnd then
			Crc = bit32.bxor(Crc, buffer.readu32(Data, Offset))
			Crc = bit32.bxor(
				buffer.readu32(Lookup3, bit32.band(Crc, 0xff) * 4),
				buffer.readu32(Lookup2, bit32.band(bit32.rshift(Crc, 8), 0xff) * 4),
				buffer.readu32(Lookup1, bit32.band(bit32.rshift(Crc, 16), 0xff) * 4),
				buffer.readu32(Lookup, bit32.rshift(Crc, 24) * 4)
			)
			Offset = Offset + 4
		end
		for TailOffset = Offset, DataEnd - 1 do
			local TableIndex = bit32.band(bit32.bxor(Crc, buffer.readu8(Data, TailOffset)), 0xff) * 4
			Crc = bit32.bxor(buffer.readu32(Lookup, TableIndex), bit32.rshift(Crc, 8))
		end
		return bit32.bxor(Crc, 0xffffffff)
	end

	local function ReverseBits(Value: number, Count: number): number
		local Result = 0
		for _ = 1, Count do
			Result = Result * 2 + bit32.band(Value, 1)
			Value = bit32.rshift(Value, 1)
		end
		return Result
	end

	local function BuildInflateHuffman(Lengths: buffer, SymbolCount: number, StartIndex: number): InflateHuffman
		local CountByLength = buffer.create((MaxLookupBits + 1) * 2)
		local NextCode = buffer.create((MaxLookupBits + 1) * 4)
		local Lookup = buffer.create(HuffmanLookupSize * 4)
		local Code = 0
		for Symbol = 0, SymbolCount - 1 do
			local Length = buffer.readu8(Lengths, StartIndex + Symbol)
			if Length > MaxLookupBits then
				error("invalid deflate Huffman length")
			end
			if Length > 0 then
				local CountOffset = Length * 2
				buffer.writeu16(CountByLength, CountOffset, buffer.readu16(CountByLength, CountOffset) + 1)
			end
		end
		local RemainingCodes = 1
		for Length = 1, MaxLookupBits do
			RemainingCodes = RemainingCodes * 2 - buffer.readu16(CountByLength, Length * 2)
			if RemainingCodes < 0 then
				error("oversubscribed deflate Huffman table")
			end
			Code = (Code + buffer.readu16(CountByLength, (Length - 1) * 2)) * 2
			buffer.writeu32(NextCode, Length * 4, Code)
		end
		for Symbol = 0, SymbolCount - 1 do
			local Length = buffer.readu8(Lengths, StartIndex + Symbol)
			if Length > 0 then
				local NextCodeOffset = Length * 4
				local CurrentCode = buffer.readu32(NextCode, NextCodeOffset)
				local ReversedCode = ReverseBits(CurrentCode, Length)
				local Stride = BitPowers[Length]
				local Replications = HuffmanLookupSize // Stride
				local Entry = Symbol + Length * 65536
				buffer.writeu32(NextCode, NextCodeOffset, CurrentCode + 1)
				for Repeat = 0, Replications - 1 do
					local LookupIndex = ReversedCode + Repeat * Stride
					buffer.writeu32(Lookup, LookupIndex * 4, Entry)
				end
			end
		end
		return {Lookup = Lookup}
	end

	local FixedLiteralHuffman = BuildInflateHuffman(FixedLiteralLengths, 288, 0)
	local FixedDistanceHuffman = BuildInflateHuffman(FixedDistanceLengths, 32, 0)

	local function EnsureInflateBits(Count: number)
		while InflateBitCount < Count and InflatePos < InflateLength do
			InflateBits = InflateBits + bit32.lshift(buffer.readu8(InflateData, InflatePos), InflateBitCount)
			InflateBitCount = InflateBitCount + 8
			InflatePos = InflatePos + 1
		end
	end

	local function ReadInflateBits(Count: number): number
		EnsureInflateBits(Count)
		if InflateBitCount < Count then
			error("unexpected end of deflate data")
		end
		local Value = bit32.band(InflateBits, BitPowers[Count] - 1)
		InflateBits = bit32.rshift(InflateBits, Count)
		InflateBitCount = InflateBitCount - Count
		return Value
	end

	local function DecodeInflateSymbol(Huffman: InflateHuffman): number
		EnsureInflateBits(MaxLookupBits)
		local LookupIndex = bit32.band(InflateBits, HuffmanLookupSize - 1)
		local Entry = buffer.readu32(Huffman.Lookup, LookupIndex * 4)
		local Length = bit32.rshift(Entry, 16)
		if Length == 0 or Length > InflateBitCount then
			error("invalid deflate Huffman code")
		end
		local Symbol = bit32.band(Entry, 0xffff)
		InflateBits = bit32.rshift(InflateBits, Length)
		InflateBitCount = InflateBitCount - Length
		return Symbol
	end

	local function WriteInflateByte(Value: number)
		if InflateOutputPos >= InflateOutputLength then
			error("deflate output exceeds expected size")
		end
		buffer.writeu8(InflateOutput, InflateOutputPos, Value)
		InflateOutputPos = InflateOutputPos + 1
	end

	local function DecodeUncompressedBlock()
		local DropBits = InflateBitCount % 8
		if DropBits > 0 then
			ReadInflateBits(DropBits)
		end
		local Length = ReadInflateBits(16)
		local Check = ReadInflateBits(16)
		if bit32.bxor(Length, 0xffff) ~= Check then
			error("invalid deflate uncompressed length")
		end
		if InflateOutputPos + Length > InflateOutputLength then
			error("invalid deflate uncompressed block size")
		end
		if InflateBitCount == 0 and InflatePos + Length <= InflateLength then
			buffer.copy(InflateOutput, InflateOutputPos, InflateData, InflatePos, Length)
			InflatePos = InflatePos + Length
			InflateOutputPos = InflateOutputPos + Length
		else
			for _ = 1, Length do
				WriteInflateByte(ReadInflateBits(8))
			end
		end
	end

	local function DecodeCompressedBlock(LiteralHuffman: InflateHuffman, DistanceHuffman: InflateHuffman)
		while true do
			local Symbol = DecodeInflateSymbol(LiteralHuffman)
			if Symbol < 256 then
				if InflateOutputPos >= InflateOutputLength then
					error("deflate output exceeds expected size")
				end
				buffer.writeu8(InflateOutput, InflateOutputPos, Symbol)
				InflateOutputPos = InflateOutputPos + 1
			elseif Symbol == 256 then
				break
			elseif Symbol <= 285 then
				local LengthIndex = Symbol - 257 + 1
				local CopyLength = LengthBase[LengthIndex]
				local LengthExtraBits = LengthExtra[LengthIndex]
				if LengthExtraBits > 0 then
					CopyLength = CopyLength + ReadInflateBits(LengthExtraBits)
				end
				local DistanceSymbol = DecodeInflateSymbol(DistanceHuffman)
				if DistanceSymbol > 29 then
					error("invalid deflate distance symbol")
				end
				local CopyDistance = DistanceBase[DistanceSymbol + 1]
				local DistanceExtraBits = DistanceExtra[DistanceSymbol + 1]
				if DistanceExtraBits > 0 then
					CopyDistance = CopyDistance + ReadInflateBits(DistanceExtraBits)
				end
				if CopyDistance > InflateOutputPos then
					error("invalid deflate distance")
				end
				if InflateOutputPos + CopyLength > InflateOutputLength then
					error("deflate output exceeds expected size")
				end
				if CopyDistance == 1 then
					buffer.fill(InflateOutput, InflateOutputPos, buffer.readu8(InflateOutput, InflateOutputPos - 1), CopyLength)
					InflateOutputPos = InflateOutputPos + CopyLength
				elseif CopyDistance >= CopyLength then
					buffer.copy(InflateOutput, InflateOutputPos, InflateOutput, InflateOutputPos - CopyDistance, CopyLength)
					InflateOutputPos = InflateOutputPos + CopyLength
				else
					for _ = 1, CopyLength do
						buffer.writeu8(InflateOutput, InflateOutputPos, buffer.readu8(InflateOutput, InflateOutputPos - CopyDistance))
						InflateOutputPos = InflateOutputPos + 1
					end
				end
			else
				error("invalid deflate literal symbol")
			end
		end
	end

	local function DecodeDynamicBlock()
		local LiteralCount = ReadInflateBits(5) + 257
		local DistanceCount = ReadInflateBits(5) + 1
		local CodeLengthCount = ReadInflateBits(4) + 4
		if LiteralCount > 286 then
			error("invalid deflate literal count")
		end
		local CodeLengthLengths = buffer.create(19)
		local Lengths = buffer.create(LiteralCount + DistanceCount)
		for Index = 1, CodeLengthCount do
			buffer.writeu8(CodeLengthLengths, CodeLengthOrder[Index], ReadInflateBits(3))
		end
		local CodeLengthHuffman = BuildInflateHuffman(CodeLengthLengths, 19, 0)
		local Index = 0
		local PreviousLength = 0
		while Index < LiteralCount + DistanceCount do
			local Symbol = DecodeInflateSymbol(CodeLengthHuffman)
			if Symbol <= 15 then
				buffer.writeu8(Lengths, Index, Symbol)
				PreviousLength = Symbol
				Index = Index + 1
			elseif Symbol == 16 then
				if Index == 0 then
					error("invalid deflate repeat length")
				end
				local RepeatCount = ReadInflateBits(2) + 3
				for _ = 1, RepeatCount do
					if Index >= LiteralCount + DistanceCount then
						error("deflate repeat exceeds table")
					end
					buffer.writeu8(Lengths, Index, PreviousLength)
					Index = Index + 1
				end
			elseif Symbol == 17 then
				local RepeatCount = ReadInflateBits(3) + 3
				PreviousLength = 0
				for _ = 1, RepeatCount do
					if Index >= LiteralCount + DistanceCount then
						error("deflate repeat exceeds table")
					end
					buffer.writeu8(Lengths, Index, 0)
					Index = Index + 1
				end
			elseif Symbol == 18 then
				local RepeatCount = ReadInflateBits(7) + 11
				PreviousLength = 0
				for _ = 1, RepeatCount do
					if Index >= LiteralCount + DistanceCount then
						error("deflate repeat exceeds table")
					end
					buffer.writeu8(Lengths, Index, 0)
					Index = Index + 1
				end
			else
				error("invalid deflate code length symbol")
			end
		end
		if buffer.readu8(Lengths, 256) == 0 then
			error("missing deflate end code")
		end
		DecodeCompressedBlock(BuildInflateHuffman(Lengths, LiteralCount, 0), BuildInflateHuffman(Lengths, DistanceCount, LiteralCount))
	end

	local function InflateZlibInternal(Compressed: buffer, Start: number, Length: number, OutputLimit: number, ExactLength: number): buffer
		if Length < 6 then
			error("truncated zlib data")
		end
		if OutputLimit > MaxOutputBytes then
			error("zlib output too large")
		end
		local CompressionMethod = buffer.readu8(Compressed, Start)
		local Flags = buffer.readu8(Compressed, Start + 1)
		if bit32.band(CompressionMethod, 15) ~= 8 or bit32.rshift(CompressionMethod, 4) > 7 then
			error("unsupported zlib compression method")
		end
		if (CompressionMethod * 256 + Flags) % 31 ~= 0 then
			error("invalid zlib header check")
		end
		if bit32.btest(Flags, 32) then
			error("zlib preset dictionaries are not supported")
		end
		InflateData = Compressed
		InflateLength = Start + Length - 4
		InflatePos = Start + 2
		InflateBits = 0
		InflateBitCount = 0
		InflateOutput = buffer.create(OutputLimit)
		InflateOutputLength = OutputLimit
		InflateOutputPos = 0
		local FinalBlock = false
		while not FinalBlock do
			FinalBlock = ReadInflateBits(1) == 1
			local BlockType = ReadInflateBits(2)
			if BlockType == 0 then
				DecodeUncompressedBlock()
			elseif BlockType == 1 then
				DecodeCompressedBlock(FixedLiteralHuffman, FixedDistanceHuffman)
			elseif BlockType == 2 then
				DecodeDynamicBlock()
			else
				error("invalid deflate block type")
			end
		end
		if InflatePos < InflateLength or InflateBitCount >= 8 then
			error("trailing zlib deflate data")
		end
		if ExactLength >= 0 and InflateOutputPos ~= ExactLength then
			error("deflate output length mismatch")
		end
		local S1 = 1
		local S2 = 0
		local AdlerOffset = 0
		local RemainingAdlerBytes = InflateOutputPos
		while RemainingAdlerBytes >= 5552 do
			RemainingAdlerBytes = RemainingAdlerBytes - 5552
			for _ = 1, 347 do
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
			end
			S1 = S1 % AdlerBase
			S2 = S2 % AdlerBase
		end
		while RemainingAdlerBytes >= 16 do
			RemainingAdlerBytes = RemainingAdlerBytes - 16
			for _ = 1, 16 do
				S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
				S2 = S2 + S1
				AdlerOffset = AdlerOffset + 1
			end
		end
		while RemainingAdlerBytes > 0 do
			S1 = S1 + buffer.readu8(InflateOutput, AdlerOffset)
			S2 = S2 + S1
			AdlerOffset = AdlerOffset + 1
			RemainingAdlerBytes = RemainingAdlerBytes - 1
		end
		S1 = S1 % AdlerBase
		S2 = S2 % AdlerBase
		local ActualAdler = S2 * 65536 + S1
		local ExpectedAdler = ReadU32BE(Compressed, Start + Length - 4)
		if ActualAdler ~= ExpectedAdler then
			error("invalid zlib Adler32")
		end
		local Output = InflateOutput
		if InflateOutputPos ~= OutputLimit then
			Output = buffer.create(InflateOutputPos)
			buffer.copy(Output, 0, InflateOutput, 0, InflateOutputPos)
		end
		InflateData = EmptyInflateData
		InflateLength = 0
		InflatePos = 0
		InflateBits = 0
		InflateBitCount = 0
		InflateOutput = EmptyInflateData
		InflateOutputPos = 0
		InflateOutputLength = 0
		return Output
	end

	local function InflateZlib(Compressed: buffer, ExpectedLength: number): buffer
		return InflateZlibInternal(Compressed, 0, buffer.len(Compressed), ExpectedLength, ExpectedLength)
	end

	local function ValidateColorType(ColorType: number, BitDepth: number): number
		if ColorType == 0 then
			if BitDepth == 1 or BitDepth == 2 or BitDepth == 4 or BitDepth == 8 or BitDepth == 16 then
				return 1
			end
		elseif ColorType == 2 then
			if BitDepth == 8 or BitDepth == 16 then
				return 3
			end
		elseif ColorType == 3 then
			if BitDepth == 1 or BitDepth == 2 or BitDepth == 4 or BitDepth == 8 then
				return 1
			end
		elseif ColorType == 4 then
			if BitDepth == 8 or BitDepth == 16 then
				return 2
			end
		elseif ColorType == 6 then
			if BitDepth == 8 or BitDepth == 16 then
				return 4
			end
		end
		error("unsupported PNG color type or bit depth")
		return 0
	end

	local function PassSize(Size: number, Start: number, Step: number): number
		if Size <= Start then
			return 0
		end
		return math.floor((Size - Start + Step - 1) / Step)
	end

	local function Paeth(Left: number, Up: number, UpLeft: number): number
		local Estimate = Left + Up - UpLeft
		local LeftDistance = Estimate - Left
		local UpDistance = Estimate - Up
		local UpLeftDistance = Estimate - UpLeft
		if LeftDistance < 0 then
			LeftDistance = -LeftDistance
		end
		if UpDistance < 0 then
			UpDistance = -UpDistance
		end
		if UpLeftDistance < 0 then
			UpLeftDistance = -UpLeftDistance
		end
		if LeftDistance <= UpDistance and LeftDistance <= UpLeftDistance then
			return Left
		elseif UpDistance <= UpLeftDistance then
			return Up
		end
		return UpLeft
	end

	local function ReconstructRow(Inflated: buffer, InflatedOffset: number, CurrentRow: buffer, PreviousRow: buffer, RowBytes: number, FilterBpp: number): number
		local Filter = buffer.readu8(Inflated, InflatedOffset)
		InflatedOffset = InflatedOffset + 1
		if Filter == 0 then
			buffer.copy(CurrentRow, 0, Inflated, InflatedOffset, RowBytes)
		elseif Filter == 1 then
			local InitialBytes = FilterBpp
			if InitialBytes > RowBytes then
				InitialBytes = RowBytes
			end
			buffer.copy(CurrentRow, 0, Inflated, InflatedOffset, InitialBytes)
			for Index = FilterBpp, RowBytes - 1 do
				buffer.writeu8(CurrentRow, Index, buffer.readu8(Inflated, InflatedOffset + Index) + buffer.readu8(CurrentRow, Index - FilterBpp))
			end
		elseif Filter == 2 then
			for Index = 0, RowBytes - 1 do
				buffer.writeu8(CurrentRow, Index, buffer.readu8(Inflated, InflatedOffset + Index) + buffer.readu8(PreviousRow, Index))
			end
		elseif Filter == 3 then
			local InitialBytes = FilterBpp
			if InitialBytes > RowBytes then
				InitialBytes = RowBytes
			end
			for Index = 0, InitialBytes - 1 do
				buffer.writeu8(CurrentRow, Index, buffer.readu8(Inflated, InflatedOffset + Index) + math.floor(buffer.readu8(PreviousRow, Index) / 2))
			end
			for Index = FilterBpp, RowBytes - 1 do
				buffer.writeu8(CurrentRow, Index, buffer.readu8(Inflated, InflatedOffset + Index) + math.floor((buffer.readu8(CurrentRow, Index - FilterBpp) + buffer.readu8(PreviousRow, Index)) / 2))
			end
		elseif Filter == 4 then
			local InitialBytes = FilterBpp
			if InitialBytes > RowBytes then
				InitialBytes = RowBytes
			end
			for Index = 0, InitialBytes - 1 do
				buffer.writeu8(CurrentRow, Index, buffer.readu8(Inflated, InflatedOffset + Index) + buffer.readu8(PreviousRow, Index))
			end
			for Index = FilterBpp, RowBytes - 1 do
				buffer.writeu8(CurrentRow, Index, buffer.readu8(Inflated, InflatedOffset + Index) + Paeth(buffer.readu8(CurrentRow, Index - FilterBpp), buffer.readu8(PreviousRow, Index), buffer.readu8(PreviousRow, Index - FilterBpp)))
			end
		else
			error("invalid PNG filter")
		end
		return InflatedOffset + RowBytes
	end

	local function DecodeRgba8NonInterlaced(Inflated: buffer, Width: number, Height: number): buffer
		local RowBytes = Width * 4
		local Output = buffer.create(RowBytes * Height)
		local InflatedOffset = 0
		for Y = 0, Height - 1 do
			local Filter = buffer.readu8(Inflated, InflatedOffset)
			InflatedOffset = InflatedOffset + 1
			local OutputOffset = Y * RowBytes
			local PreviousOffset = OutputOffset - RowBytes
			if Filter == 0 then
				buffer.copy(Output, OutputOffset, Inflated, InflatedOffset, RowBytes)
			elseif Filter == 1 or (Filter == 4 and Y == 0) then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local LeftRed = 0
				local LeftGreen = 0
				local LeftBlue = 0
				local LeftAlpha = 0
				for _ = 1, Width do
					LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + LeftRed, 0xff)
					LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + LeftGreen, 0xff)
					LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + LeftBlue, 0xff)
					LeftAlpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 3) + LeftAlpha, 0xff)
					buffer.writeu32(Output, TargetOffset, LeftRed + LeftGreen * 256 + LeftBlue * 65536 + LeftAlpha * 16777216)
					SourceOffset = SourceOffset + 4
					TargetOffset = TargetOffset + 4
				end
			elseif Filter == 2 then
				if Y == 0 then
					buffer.copy(Output, OutputOffset, Inflated, InflatedOffset, RowBytes)
				else
					local SourceOffset = InflatedOffset
					local TargetOffset = OutputOffset
					local UpOffset = PreviousOffset
					for _ = 1, Width do
						local Red = bit32.band(buffer.readu8(Inflated, SourceOffset) + buffer.readu8(Output, UpOffset), 0xff)
						local Green = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + buffer.readu8(Output, UpOffset + 1), 0xff)
						local Blue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + buffer.readu8(Output, UpOffset + 2), 0xff)
						local Alpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 3) + buffer.readu8(Output, UpOffset + 3), 0xff)
						buffer.writeu32(Output, TargetOffset, Red + Green * 256 + Blue * 65536 + Alpha * 16777216)
						SourceOffset = SourceOffset + 4
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				end
			elseif Filter == 3 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				local LeftRed = 0
				local LeftGreen = 0
				local LeftBlue = 0
				local LeftAlpha = 0
				if Y == 0 then
					for _ = 1, Width do
						LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor(LeftRed / 2), 0xff)
						LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + math.floor(LeftGreen / 2), 0xff)
						LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + math.floor(LeftBlue / 2), 0xff)
						LeftAlpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 3) + math.floor(LeftAlpha / 2), 0xff)
						buffer.writeu32(Output, TargetOffset, LeftRed + LeftGreen * 256 + LeftBlue * 65536 + LeftAlpha * 16777216)
						SourceOffset = SourceOffset + 4
						TargetOffset = TargetOffset + 4
					end
				else
					for _ = 1, Width do
						LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor((LeftRed + buffer.readu8(Output, UpOffset)) / 2), 0xff)
						LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + math.floor((LeftGreen + buffer.readu8(Output, UpOffset + 1)) / 2), 0xff)
						LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + math.floor((LeftBlue + buffer.readu8(Output, UpOffset + 2)) / 2), 0xff)
						LeftAlpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 3) + math.floor((LeftAlpha + buffer.readu8(Output, UpOffset + 3)) / 2), 0xff)
						buffer.writeu32(Output, TargetOffset, LeftRed + LeftGreen * 256 + LeftBlue * 65536 + LeftAlpha * 16777216)
						SourceOffset = SourceOffset + 4
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				end
			elseif Filter == 4 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				local UpLeftRed = 0
				local UpLeftGreen = 0
				local UpLeftBlue = 0
				local UpLeftAlpha = 0
				local LeftRed = 0
				local LeftGreen = 0
				local LeftBlue = 0
				local LeftAlpha = 0
				for _ = 1, Width do
					local UpRed = buffer.readu8(Output, UpOffset)
					local UpGreen = buffer.readu8(Output, UpOffset + 1)
					local UpBlue = buffer.readu8(Output, UpOffset + 2)
					local UpAlpha = buffer.readu8(Output, UpOffset + 3)
					LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + Paeth(LeftRed, UpRed, UpLeftRed), 0xff)
					LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + Paeth(LeftGreen, UpGreen, UpLeftGreen), 0xff)
					LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + Paeth(LeftBlue, UpBlue, UpLeftBlue), 0xff)
					LeftAlpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 3) + Paeth(LeftAlpha, UpAlpha, UpLeftAlpha), 0xff)
					buffer.writeu32(Output, TargetOffset, LeftRed + LeftGreen * 256 + LeftBlue * 65536 + LeftAlpha * 16777216)
					UpLeftRed = UpRed
					UpLeftGreen = UpGreen
					UpLeftBlue = UpBlue
					UpLeftAlpha = UpAlpha
					SourceOffset = SourceOffset + 4
					TargetOffset = TargetOffset + 4
					UpOffset = UpOffset + 4
				end
			else
				error("invalid PNG filter")
			end
			InflatedOffset = InflatedOffset + RowBytes
		end
		if InflatedOffset ~= buffer.len(Inflated) then
			error("PNG image data length mismatch")
		end
		return Output
	end

	local function DecodeRgb8NonInterlaced(Inflated: buffer, Width: number, Height: number, TransparentRed: number, TransparentGreen: number, TransparentBlue: number): buffer
		local OutputRowBytes = Width * 4
		local InputRowBytes = Width * 3
		local Output = buffer.create(OutputRowBytes * Height)
		local TransparentRgb = TransparentRed + TransparentGreen * 256 + TransparentBlue * 65536
		local InflatedOffset = 0
		for Y = 0, Height - 1 do
			local Filter = buffer.readu8(Inflated, InflatedOffset)
			InflatedOffset = InflatedOffset + 1
			local OutputOffset = Y * OutputRowBytes
			local PreviousOffset = OutputOffset - OutputRowBytes
			if Filter == 0 or (Filter == 2 and Y == 0) then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				if TransparentRed < 0 then
					for _ = 1, Width do
						buffer.writeu32(Output, TargetOffset, 0xff000000 + buffer.readu16(Inflated, SourceOffset) + buffer.readu8(Inflated, SourceOffset + 2) * 65536)
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
					end
				else
					for _ = 1, Width do
						local Rgb = buffer.readu16(Inflated, SourceOffset) + buffer.readu8(Inflated, SourceOffset + 2) * 65536
						local Alpha = 255
						if Rgb == TransparentRgb then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Rgb + Alpha * 16777216)
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
					end
				end
			elseif Filter == 1 or (Filter == 4 and Y == 0) then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local LeftRed = 0
				local LeftGreen = 0
				local LeftBlue = 0
				if TransparentRed < 0 then
					for _ = 1, Width do
						LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + LeftRed, 0xff)
						LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + LeftGreen, 0xff)
						LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + LeftBlue, 0xff)
						buffer.writeu32(Output, TargetOffset, 0xff000000 + LeftRed + LeftGreen * 256 + LeftBlue * 65536)
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
					end
				else
					for _ = 1, Width do
						LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + LeftRed, 0xff)
						LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + LeftGreen, 0xff)
						LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + LeftBlue, 0xff)
						local Rgb = LeftRed + LeftGreen * 256 + LeftBlue * 65536
						local Alpha = 255
						if Rgb == TransparentRgb then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Rgb + Alpha * 16777216)
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
					end
				end
			elseif Filter == 2 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				if TransparentRed < 0 then
					for _ = 1, Width do
						local Red = bit32.band(buffer.readu8(Inflated, SourceOffset) + buffer.readu8(Output, UpOffset), 0xff)
						local Green = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + buffer.readu8(Output, UpOffset + 1), 0xff)
						local Blue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + buffer.readu8(Output, UpOffset + 2), 0xff)
						buffer.writeu32(Output, TargetOffset, 0xff000000 + Red + Green * 256 + Blue * 65536)
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				else
					for _ = 1, Width do
						local Red = bit32.band(buffer.readu8(Inflated, SourceOffset) + buffer.readu8(Output, UpOffset), 0xff)
						local Green = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + buffer.readu8(Output, UpOffset + 1), 0xff)
						local Blue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + buffer.readu8(Output, UpOffset + 2), 0xff)
						local Rgb = Red + Green * 256 + Blue * 65536
						local Alpha = 255
						if Rgb == TransparentRgb then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Rgb + Alpha * 16777216)
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				end
			elseif Filter == 3 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				local LeftRed = 0
				local LeftGreen = 0
				local LeftBlue = 0
				if Y == 0 then
					if TransparentRed < 0 then
						for _ = 1, Width do
							LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor(LeftRed / 2), 0xff)
							LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + math.floor(LeftGreen / 2), 0xff)
							LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + math.floor(LeftBlue / 2), 0xff)
							buffer.writeu32(Output, TargetOffset, 0xff000000 + LeftRed + LeftGreen * 256 + LeftBlue * 65536)
							SourceOffset = SourceOffset + 3
							TargetOffset = TargetOffset + 4
						end
					else
						for _ = 1, Width do
							LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor(LeftRed / 2), 0xff)
							LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + math.floor(LeftGreen / 2), 0xff)
							LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + math.floor(LeftBlue / 2), 0xff)
							local Rgb = LeftRed + LeftGreen * 256 + LeftBlue * 65536
							local Alpha = 255
							if Rgb == TransparentRgb then
								Alpha = 0
							end
							buffer.writeu32(Output, TargetOffset, Rgb + Alpha * 16777216)
							SourceOffset = SourceOffset + 3
							TargetOffset = TargetOffset + 4
						end
					end
				elseif TransparentRed < 0 then
					for _ = 1, Width do
						LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor((LeftRed + buffer.readu8(Output, UpOffset)) / 2), 0xff)
						LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + math.floor((LeftGreen + buffer.readu8(Output, UpOffset + 1)) / 2), 0xff)
						LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + math.floor((LeftBlue + buffer.readu8(Output, UpOffset + 2)) / 2), 0xff)
						buffer.writeu32(Output, TargetOffset, 0xff000000 + LeftRed + LeftGreen * 256 + LeftBlue * 65536)
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				else
					for _ = 1, Width do
						LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor((LeftRed + buffer.readu8(Output, UpOffset)) / 2), 0xff)
						LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + math.floor((LeftGreen + buffer.readu8(Output, UpOffset + 1)) / 2), 0xff)
						LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + math.floor((LeftBlue + buffer.readu8(Output, UpOffset + 2)) / 2), 0xff)
						local Rgb = LeftRed + LeftGreen * 256 + LeftBlue * 65536
						local Alpha = 255
						if Rgb == TransparentRgb then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Rgb + Alpha * 16777216)
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				end
			elseif Filter == 4 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				local UpLeftRed = 0
				local UpLeftGreen = 0
				local UpLeftBlue = 0
				local LeftRed = 0
				local LeftGreen = 0
				local LeftBlue = 0
				if TransparentRed < 0 then
					for _ = 1, Width do
						local UpRed = buffer.readu8(Output, UpOffset)
						local UpGreen = buffer.readu8(Output, UpOffset + 1)
						local UpBlue = buffer.readu8(Output, UpOffset + 2)
						LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + Paeth(LeftRed, UpRed, UpLeftRed), 0xff)
						LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + Paeth(LeftGreen, UpGreen, UpLeftGreen), 0xff)
						LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + Paeth(LeftBlue, UpBlue, UpLeftBlue), 0xff)
						buffer.writeu32(Output, TargetOffset, 0xff000000 + LeftRed + LeftGreen * 256 + LeftBlue * 65536)
						UpLeftRed = UpRed
						UpLeftGreen = UpGreen
						UpLeftBlue = UpBlue
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				else
					for _ = 1, Width do
						local UpRed = buffer.readu8(Output, UpOffset)
						local UpGreen = buffer.readu8(Output, UpOffset + 1)
						local UpBlue = buffer.readu8(Output, UpOffset + 2)
						LeftRed = bit32.band(buffer.readu8(Inflated, SourceOffset) + Paeth(LeftRed, UpRed, UpLeftRed), 0xff)
						LeftGreen = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + Paeth(LeftGreen, UpGreen, UpLeftGreen), 0xff)
						LeftBlue = bit32.band(buffer.readu8(Inflated, SourceOffset + 2) + Paeth(LeftBlue, UpBlue, UpLeftBlue), 0xff)
						local Rgb = LeftRed + LeftGreen * 256 + LeftBlue * 65536
						local Alpha = 255
						if Rgb == TransparentRgb then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Rgb + Alpha * 16777216)
						UpLeftRed = UpRed
						UpLeftGreen = UpGreen
						UpLeftBlue = UpBlue
						SourceOffset = SourceOffset + 3
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				end
			else
				error("invalid PNG filter")
			end
			InflatedOffset = InflatedOffset + InputRowBytes
		end
		if InflatedOffset ~= buffer.len(Inflated) then
			error("PNG image data length mismatch")
		end
		return Output
	end

	local function DecodeGray8NonInterlaced(Inflated: buffer, Width: number, Height: number, TransparentGray: number): buffer
		local OutputRowBytes = Width * 4
		local Output = buffer.create(OutputRowBytes * Height)
		local InflatedOffset = 0
		for Y = 0, Height - 1 do
			local Filter = buffer.readu8(Inflated, InflatedOffset)
			InflatedOffset = InflatedOffset + 1
			local OutputOffset = Y * OutputRowBytes
			local PreviousOffset = OutputOffset - OutputRowBytes
			if Filter == 0 or (Filter == 2 and Y == 0) then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				if TransparentGray < 0 then
					for _ = 1, Width do
						local Gray = buffer.readu8(Inflated, SourceOffset)
						buffer.writeu32(Output, TargetOffset, 0xff000000 + Gray * 65793)
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
					end
				else
					for _ = 1, Width do
						local Gray = buffer.readu8(Inflated, SourceOffset)
						local Alpha = 255
						if Gray == TransparentGray then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Alpha * 16777216 + Gray * 65793)
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
					end
				end
			elseif Filter == 1 or (Filter == 4 and Y == 0) then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local Left = 0
				if TransparentGray < 0 then
					for _ = 1, Width do
						Left = bit32.band(buffer.readu8(Inflated, SourceOffset) + Left, 0xff)
						buffer.writeu32(Output, TargetOffset, 0xff000000 + Left * 65793)
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
					end
				else
					for _ = 1, Width do
						Left = bit32.band(buffer.readu8(Inflated, SourceOffset) + Left, 0xff)
						local Alpha = 255
						if Left == TransparentGray then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Alpha * 16777216 + Left * 65793)
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
					end
				end
			elseif Filter == 2 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				if TransparentGray < 0 then
					for _ = 1, Width do
						local Gray = bit32.band(buffer.readu8(Inflated, SourceOffset) + buffer.readu8(Output, UpOffset), 0xff)
						buffer.writeu32(Output, TargetOffset, 0xff000000 + Gray * 65793)
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				else
					for _ = 1, Width do
						local Gray = bit32.band(buffer.readu8(Inflated, SourceOffset) + buffer.readu8(Output, UpOffset), 0xff)
						local Alpha = 255
						if Gray == TransparentGray then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Alpha * 16777216 + Gray * 65793)
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				end
			elseif Filter == 3 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				local Left = 0
				if Y == 0 then
					if TransparentGray < 0 then
						for _ = 1, Width do
							Left = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor(Left / 2), 0xff)
							buffer.writeu32(Output, TargetOffset, 0xff000000 + Left * 65793)
							SourceOffset = SourceOffset + 1
							TargetOffset = TargetOffset + 4
						end
					else
						for _ = 1, Width do
							Left = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor(Left / 2), 0xff)
							local Alpha = 255
							if Left == TransparentGray then
								Alpha = 0
							end
							buffer.writeu32(Output, TargetOffset, Alpha * 16777216 + Left * 65793)
							SourceOffset = SourceOffset + 1
							TargetOffset = TargetOffset + 4
						end
					end
				elseif TransparentGray < 0 then
					for _ = 1, Width do
						Left = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor((Left + buffer.readu8(Output, UpOffset)) / 2), 0xff)
						buffer.writeu32(Output, TargetOffset, 0xff000000 + Left * 65793)
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				else
					for _ = 1, Width do
						Left = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor((Left + buffer.readu8(Output, UpOffset)) / 2), 0xff)
						local Alpha = 255
						if Left == TransparentGray then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Alpha * 16777216 + Left * 65793)
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				end
			elseif Filter == 4 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				local UpLeft = 0
				local Left = 0
				if TransparentGray < 0 then
					for _ = 1, Width do
						local Up = bit32.band(buffer.readu8(Output, UpOffset), 0xff)
						Left = bit32.band(buffer.readu8(Inflated, SourceOffset) + Paeth(Left, Up, UpLeft), 0xff)
						buffer.writeu32(Output, TargetOffset, 0xff000000 + Left * 65793)
						UpLeft = Up
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				else
					for _ = 1, Width do
						local Up = buffer.readu8(Output, UpOffset)
						Left = bit32.band(buffer.readu8(Inflated, SourceOffset) + Paeth(Left, Up, UpLeft), 0xff)
						local Alpha = 255
						if Left == TransparentGray then
							Alpha = 0
						end
						buffer.writeu32(Output, TargetOffset, Alpha * 16777216 + Left * 65793)
						UpLeft = Up
						SourceOffset = SourceOffset + 1
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				end
			else
				error("invalid PNG filter")
			end
			InflatedOffset = InflatedOffset + Width
		end
		if InflatedOffset ~= buffer.len(Inflated) then
			error("PNG image data length mismatch")
		end
		return Output
	end

	local function DecodeGrayAlpha8NonInterlaced(Inflated: buffer, Width: number, Height: number): buffer
		local OutputRowBytes = Width * 4
		local InputRowBytes = Width * 2
		local Output = buffer.create(OutputRowBytes * Height)
		local InflatedOffset = 0
		for Y = 0, Height - 1 do
			local Filter = buffer.readu8(Inflated, InflatedOffset)
			InflatedOffset = InflatedOffset + 1
			local OutputOffset = Y * OutputRowBytes
			local PreviousOffset = OutputOffset - OutputRowBytes
			if Filter == 0 or (Filter == 2 and Y == 0) then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				for _ = 1, Width do
					local GrayAlpha = buffer.readu16(Inflated, SourceOffset)
					local Gray = bit32.band(GrayAlpha, 0xff)
					local Alpha = bit32.rshift(GrayAlpha, 8)
					buffer.writeu32(Output, TargetOffset, Alpha * 16777216 + Gray * 65793)
					SourceOffset = SourceOffset + 2
					TargetOffset = TargetOffset + 4
				end
			elseif Filter == 1 or (Filter == 4 and Y == 0) then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local LeftGray = 0
				local LeftAlpha = 0
				for _ = 1, Width do
					LeftGray = bit32.band(buffer.readu8(Inflated, SourceOffset) + LeftGray, 0xff)
					LeftAlpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + LeftAlpha, 0xff)
					buffer.writeu32(Output, TargetOffset, LeftAlpha * 16777216 + LeftGray * 65793)
					SourceOffset = SourceOffset + 2
					TargetOffset = TargetOffset + 4
				end
			elseif Filter == 2 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				for _ = 1, Width do
					local Gray = bit32.band(buffer.readu8(Inflated, SourceOffset) + buffer.readu8(Output, UpOffset), 0xff)
					local Alpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + buffer.readu8(Output, UpOffset + 3), 0xff)
					buffer.writeu32(Output, TargetOffset, Alpha * 16777216 + Gray * 65793)
					SourceOffset = SourceOffset + 2
					TargetOffset = TargetOffset + 4
					UpOffset = UpOffset + 4
				end
			elseif Filter == 3 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				local LeftGray = 0
				local LeftAlpha = 0
				if Y == 0 then
					for _ = 1, Width do
						LeftGray = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor(LeftGray / 2), 0xff)
						LeftAlpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + math.floor(LeftAlpha / 2), 0xff)
						buffer.writeu32(Output, TargetOffset, LeftAlpha * 16777216 + LeftGray * 65793)
						SourceOffset = SourceOffset + 2
						TargetOffset = TargetOffset + 4
					end
				else
					for _ = 1, Width do
						LeftGray = bit32.band(buffer.readu8(Inflated, SourceOffset) + math.floor((LeftGray + buffer.readu8(Output, UpOffset)) / 2), 0xff)
						LeftAlpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + math.floor((LeftAlpha + buffer.readu8(Output, UpOffset + 3)) / 2), 0xff)
						buffer.writeu32(Output, TargetOffset, LeftAlpha * 16777216 + LeftGray * 65793)
						SourceOffset = SourceOffset + 2
						TargetOffset = TargetOffset + 4
						UpOffset = UpOffset + 4
					end
				end
			elseif Filter == 4 then
				local SourceOffset = InflatedOffset
				local TargetOffset = OutputOffset
				local UpOffset = PreviousOffset
				local UpLeftGray = 0
				local UpLeftAlpha = 0
				local LeftGray = 0
				local LeftAlpha = 0
				for _ = 1, Width do
					local UpGray = buffer.readu8(Output, UpOffset)
					local UpAlpha = buffer.readu8(Output, UpOffset + 3)
					LeftGray = bit32.band(buffer.readu8(Inflated, SourceOffset) + Paeth(LeftGray, UpGray, UpLeftGray), 0xff)
					LeftAlpha = bit32.band(buffer.readu8(Inflated, SourceOffset + 1) + Paeth(LeftAlpha, UpAlpha, UpLeftAlpha), 0xff)
					buffer.writeu32(Output, TargetOffset, LeftAlpha * 16777216 + LeftGray * 65793)
					UpLeftGray = UpGray
					UpLeftAlpha = UpAlpha
					SourceOffset = SourceOffset + 2
					TargetOffset = TargetOffset + 4
					UpOffset = UpOffset + 4
				end
			else
				error("invalid PNG filter")
			end
			InflatedOffset = InflatedOffset + InputRowBytes
		end
		if InflatedOffset ~= buffer.len(Inflated) then
			error("PNG image data length mismatch")
		end
		return Output
	end

	local function DecodePalette8NonInterlaced(Inflated: buffer, Width: number, Height: number, Palette: buffer, PaletteEntries: number): buffer
		local OutputRowBytes = Width * 4
		local Output = buffer.create(OutputRowBytes * Height)
		local CurrentRow = buffer.create(Width)
		local PreviousRow = buffer.create(Width)
		local InflatedOffset = 0
		for Y = 0, Height - 1 do
			InflatedOffset = ReconstructRow(Inflated, InflatedOffset, CurrentRow, PreviousRow, Width, 1)
			local OutputOffset = Y * OutputRowBytes
			local TargetOffset = OutputOffset
			if PaletteEntries == 256 then
				for X = 0, Width - 1 do
					local PaletteIndex = buffer.readu8(CurrentRow, X)
					buffer.writeu32(Output, TargetOffset, buffer.readu32(Palette, PaletteIndex * 4))
					TargetOffset = TargetOffset + 4
				end
			else
				for X = 0, Width - 1 do
					local PaletteIndex = buffer.readu8(CurrentRow, X)
					if PaletteIndex >= PaletteEntries then
						error("PNG palette index out of range")
					end
					buffer.writeu32(Output, TargetOffset, buffer.readu32(Palette, PaletteIndex * 4))
					TargetOffset = TargetOffset + 4
				end
			end
			local SwapRow = PreviousRow
			PreviousRow = CurrentRow
			CurrentRow = SwapRow
		end
		if InflatedOffset ~= buffer.len(Inflated) then
			error("PNG image data length mismatch")
		end
		return Output
	end

	local function ReadPackedSample(Row: buffer, BitDepth: number, PixelIndex: number): number
		if BitDepth == 8 then
			return buffer.readu8(Row, PixelIndex)
		elseif BitDepth == 4 then
			return bit32.extract(buffer.readu8(Row, math.floor(PixelIndex / 2)), 4 - (PixelIndex % 2) * 4, 4)
		elseif BitDepth == 2 then
			return bit32.extract(buffer.readu8(Row, math.floor(PixelIndex / 4)), 6 - (PixelIndex % 4) * 2, 2)
		end
		return bit32.extract(buffer.readu8(Row, math.floor(PixelIndex / 8)), 7 - PixelIndex % 8, 1)
	end

	local function ScaleSample(Value: number, BitDepth: number): number
		if BitDepth == 1 then
			return Value * 255
		elseif BitDepth == 2 then
			return Value * 85
		elseif BitDepth == 4 then
			return Value * 17
		end
		return Value
	end

	local function WritePixel(Output: buffer, OutputOffset: number, Row: buffer, PixelIndex: number, ColorType: number, BitDepth: number, Palette: buffer, PaletteEntries: number, TransparentGray: number, TransparentRed: number, TransparentGreen: number, TransparentBlue: number)
		local Red = 0
		local Green = 0
		local Blue = 0
		local Alpha = 255
		if ColorType == 0 then
			if BitDepth == 16 then
				local Offset = PixelIndex * 2
				Red = buffer.readu8(Row, Offset)
				Green = Red
				Blue = Red
				if TransparentGray >= 0 and ReadU16BE(Row, Offset) == TransparentGray then
					Alpha = 0
				end
			else
				local Gray = ReadPackedSample(Row, BitDepth, PixelIndex)
				Red = ScaleSample(Gray, BitDepth)
				Green = Red
				Blue = Red
				if Gray == TransparentGray then
					Alpha = 0
				end
			end
		elseif ColorType == 2 then
			if BitDepth == 16 then
				local Offset = PixelIndex * 6
				Red = buffer.readu8(Row, Offset)
				Green = buffer.readu8(Row, Offset + 2)
				Blue = buffer.readu8(Row, Offset + 4)
				if TransparentRed >= 0 and ReadU16BE(Row, Offset) == TransparentRed and ReadU16BE(Row, Offset + 2) == TransparentGreen and ReadU16BE(Row, Offset + 4) == TransparentBlue then
					Alpha = 0
				end
			else
				local Offset = PixelIndex * 3
				Red = buffer.readu8(Row, Offset)
				Green = buffer.readu8(Row, Offset + 1)
				Blue = buffer.readu8(Row, Offset + 2)
				if Red == TransparentRed and Green == TransparentGreen and Blue == TransparentBlue then
					Alpha = 0
				end
			end
		elseif ColorType == 3 then
			local PaletteIndex = ReadPackedSample(Row, BitDepth, PixelIndex)
			if PaletteIndex >= PaletteEntries then
				error("PNG palette index out of range")
			end
			buffer.writeu32(Output, OutputOffset, buffer.readu32(Palette, PaletteIndex * 4))
			return
		elseif ColorType == 4 then
			if BitDepth == 16 then
				local Offset = PixelIndex * 4
				Red = buffer.readu8(Row, Offset)
				Green = Red
				Blue = Red
				Alpha = buffer.readu8(Row, Offset + 2)
			else
				local Offset = PixelIndex * 2
				Red = buffer.readu8(Row, Offset)
				Green = Red
				Blue = Red
				Alpha = buffer.readu8(Row, Offset + 1)
			end
		else
			if BitDepth == 16 then
				local Offset = PixelIndex * 8
				Red = buffer.readu8(Row, Offset)
				Green = buffer.readu8(Row, Offset + 2)
				Blue = buffer.readu8(Row, Offset + 4)
				Alpha = buffer.readu8(Row, Offset + 6)
			else
				local Offset = PixelIndex * 4
				Red = buffer.readu8(Row, Offset)
				Green = buffer.readu8(Row, Offset + 1)
				Blue = buffer.readu8(Row, Offset + 2)
				Alpha = buffer.readu8(Row, Offset + 3)
			end
		end
		buffer.writeu32(Output, OutputOffset, Red + Green * 256 + Blue * 65536 + Alpha * 16777216)
	end

	local function WriteFastRow(Output: buffer, OutputOffset: number, Row: buffer, Width: number, ColorType: number, BitDepth: number, Palette: buffer, PaletteEntries: number, TransparentGray: number, TransparentRed: number, TransparentGreen: number, TransparentBlue: number): boolean
		if ColorType == 6 and BitDepth == 8 then
			buffer.copy(Output, OutputOffset, Row, 0, Width * 4)
			return true
		elseif ColorType == 6 and BitDepth == 16 then
			local SourceOffset = 0
			for _ = 1, Width do
				local Red = buffer.readu8(Row, SourceOffset)
				local Green = buffer.readu8(Row, SourceOffset + 2)
				local Blue = buffer.readu8(Row, SourceOffset + 4)
				local Alpha = buffer.readu8(Row, SourceOffset + 6)
				buffer.writeu32(Output, OutputOffset, Red + Green * 256 + Blue * 65536 + Alpha * 16777216)
				SourceOffset = SourceOffset + 8
				OutputOffset = OutputOffset + 4
			end
			return true
		elseif ColorType == 2 and BitDepth == 8 then
			local SourceOffset = 0
			if TransparentRed < 0 then
				for _ = 1, Width do
					buffer.writeu32(Output, OutputOffset, 0xff000000 + buffer.readu16(Row, SourceOffset) + buffer.readu8(Row, SourceOffset + 2) * 65536)
					SourceOffset = SourceOffset + 3
					OutputOffset = OutputOffset + 4
				end
			else
				local TransparentRgb = TransparentRed + TransparentGreen * 256 + TransparentBlue * 65536
				for _ = 1, Width do
					local Rgb = buffer.readu16(Row, SourceOffset) + buffer.readu8(Row, SourceOffset + 2) * 65536
					local Alpha = 255
					if Rgb == TransparentRgb then
						Alpha = 0
					end
					buffer.writeu32(Output, OutputOffset, Rgb + Alpha * 16777216)
					SourceOffset = SourceOffset + 3
					OutputOffset = OutputOffset + 4
				end
			end
			return true
		elseif ColorType == 2 and BitDepth == 16 then
			local SourceOffset = 0
			if TransparentRed < 0 then
				for _ = 1, Width do
					local Red = buffer.readu8(Row, SourceOffset)
					local Green = buffer.readu8(Row, SourceOffset + 2)
					local Blue = buffer.readu8(Row, SourceOffset + 4)
					buffer.writeu32(Output, OutputOffset, 0xff000000 + Red + Green * 256 + Blue * 65536)
					SourceOffset = SourceOffset + 6
					OutputOffset = OutputOffset + 4
				end
			else
				for _ = 1, Width do
					local Red16 = ReadU16BE(Row, SourceOffset)
					local Green16 = ReadU16BE(Row, SourceOffset + 2)
					local Blue16 = ReadU16BE(Row, SourceOffset + 4)
					local Red = buffer.readu8(Row, SourceOffset)
					local Green = buffer.readu8(Row, SourceOffset + 2)
					local Blue = buffer.readu8(Row, SourceOffset + 4)
					local Alpha = 255
					if Red16 == TransparentRed and Green16 == TransparentGreen and Blue16 == TransparentBlue then
						Alpha = 0
					end
					buffer.writeu32(Output, OutputOffset, Red + Green * 256 + Blue * 65536 + Alpha * 16777216)
					SourceOffset = SourceOffset + 6
					OutputOffset = OutputOffset + 4
				end
			end
			return true
		elseif ColorType == 3 and BitDepth == 8 then
			for X = 0, Width - 1 do
				local PaletteIndex = buffer.readu8(Row, X)
				if PaletteIndex >= PaletteEntries then
					error("PNG palette index out of range")
				end
				buffer.writeu32(Output, OutputOffset, buffer.readu32(Palette, PaletteIndex * 4))
				OutputOffset = OutputOffset + 4
			end
			return true
		elseif ColorType == 3 then
			local SourceOffset = 0
			local PixelIndex = 0
			while PixelIndex < Width do
				local Packed = buffer.readu8(Row, SourceOffset)
				SourceOffset = SourceOffset + 1
				for Shift = 8 - BitDepth, 0, -BitDepth do
					local PaletteIndex = bit32.extract(Packed, Shift, BitDepth)
					if PaletteIndex >= PaletteEntries then
						error("PNG palette index out of range")
					end
					buffer.writeu32(Output, OutputOffset, buffer.readu32(Palette, PaletteIndex * 4))
					OutputOffset = OutputOffset + 4
					PixelIndex = PixelIndex + 1
					if PixelIndex >= Width then
						break
					end
				end
			end
			return true
		elseif ColorType == 0 and BitDepth == 8 then
			if TransparentGray < 0 then
				for X = 0, Width - 1 do
					local Gray = buffer.readu8(Row, X)
					buffer.writeu32(Output, OutputOffset, 0xff000000 + Gray * 65793)
					OutputOffset = OutputOffset + 4
				end
			else
				for X = 0, Width - 1 do
					local Gray = buffer.readu8(Row, X)
					local Alpha = 255
					if Gray == TransparentGray then
						Alpha = 0
					end
					buffer.writeu32(Output, OutputOffset, Alpha * 16777216 + Gray * 65793)
					OutputOffset = OutputOffset + 4
				end
			end
			return true
		elseif ColorType == 0 and BitDepth < 8 then
			local Scale = 17
			if BitDepth == 1 then
				Scale = 255
			elseif BitDepth == 2 then
				Scale = 85
			end
			local SourceOffset = 0
			local PixelIndex = 0
			while PixelIndex < Width do
				local Packed = buffer.readu8(Row, SourceOffset)
				SourceOffset = SourceOffset + 1
				for Shift = 8 - BitDepth, 0, -BitDepth do
					local GraySample = bit32.extract(Packed, Shift, BitDepth)
					local Gray = GraySample * Scale
					local Alpha = 255
					if GraySample == TransparentGray then
						Alpha = 0
					end
					buffer.writeu32(Output, OutputOffset, Alpha * 16777216 + Gray * 65793)
					OutputOffset = OutputOffset + 4
					PixelIndex = PixelIndex + 1
					if PixelIndex >= Width then
						break
					end
				end
			end
			return true
		elseif ColorType == 0 and BitDepth == 16 then
			local SourceOffset = 0
			if TransparentGray < 0 then
				for _ = 1, Width do
					local Gray = buffer.readu8(Row, SourceOffset)
					buffer.writeu32(Output, OutputOffset, 0xff000000 + Gray * 65793)
					SourceOffset = SourceOffset + 2
					OutputOffset = OutputOffset + 4
				end
			else
				for _ = 1, Width do
					local Gray16 = ReadU16BE(Row, SourceOffset)
					local Gray = buffer.readu8(Row, SourceOffset)
					local Alpha = 255
					if Gray16 == TransparentGray then
						Alpha = 0
					end
					buffer.writeu32(Output, OutputOffset, Alpha * 16777216 + Gray * 65793)
					SourceOffset = SourceOffset + 2
					OutputOffset = OutputOffset + 4
				end
			end
			return true
		elseif ColorType == 4 and BitDepth == 8 then
			local SourceOffset = 0
			for _ = 1, Width do
				local GrayAlpha = buffer.readu16(Row, SourceOffset)
				local Gray = bit32.band(GrayAlpha, 0xff)
				local Alpha = bit32.rshift(GrayAlpha, 8)
				buffer.writeu32(Output, OutputOffset, Alpha * 16777216 + Gray * 65793)
				SourceOffset = SourceOffset + 2
				OutputOffset = OutputOffset + 4
			end
			return true
		elseif ColorType == 4 and BitDepth == 16 then
			local SourceOffset = 0
			for _ = 1, Width do
				local Gray = buffer.readu8(Row, SourceOffset)
				local Alpha = buffer.readu8(Row, SourceOffset + 2)
				buffer.writeu32(Output, OutputOffset, Alpha * 16777216 + Gray * 65793)
				SourceOffset = SourceOffset + 4
				OutputOffset = OutputOffset + 4
			end
			return true
		end
		return false
	end

	local function DecodePixels(Inflated: buffer, Width: number, Height: number, ColorType: number, BitDepth: number, Channels: number, InterlaceMethod: number, Palette: buffer, PaletteEntries: number, TransparentGray: number, TransparentRed: number, TransparentGreen: number, TransparentBlue: number): buffer
		if InterlaceMethod == 0 and ColorType == 6 and BitDepth == 8 then
			return DecodeRgba8NonInterlaced(Inflated, Width, Height)
		elseif InterlaceMethod == 0 and ColorType == 2 and BitDepth == 8 then
			return DecodeRgb8NonInterlaced(Inflated, Width, Height, TransparentRed, TransparentGreen, TransparentBlue)
		elseif InterlaceMethod == 0 and ColorType == 0 and BitDepth == 8 then
			return DecodeGray8NonInterlaced(Inflated, Width, Height, TransparentGray)
		elseif InterlaceMethod == 0 and ColorType == 4 and BitDepth == 8 then
			return DecodeGrayAlpha8NonInterlaced(Inflated, Width, Height)
		elseif InterlaceMethod == 0 and ColorType == 3 and BitDepth == 8 then
			return DecodePalette8NonInterlaced(Inflated, Width, Height, Palette, PaletteEntries)
		end
		local Output = buffer.create(Width * Height * 4)
		local BitsPerPixel = Channels * BitDepth
		local FilterBpp = math.max(1, math.floor((BitsPerPixel + 7) / 8))
		local InflatedOffset = 0
		if InterlaceMethod == 0 then
			local RowBytes = math.floor((Width * BitsPerPixel + 7) / 8)
			local CurrentRow = buffer.create(RowBytes)
			local PreviousRow = buffer.create(RowBytes)
			for Y = 0, Height - 1 do
				InflatedOffset = ReconstructRow(Inflated, InflatedOffset, CurrentRow, PreviousRow, RowBytes, FilterBpp)
				local OutputOffset = Y * Width * 4
				if not WriteFastRow(Output, OutputOffset, CurrentRow, Width, ColorType, BitDepth, Palette, PaletteEntries, TransparentGray, TransparentRed, TransparentGreen, TransparentBlue) then
					for X = 0, Width - 1 do
						WritePixel(Output, OutputOffset + X * 4, CurrentRow, X, ColorType, BitDepth, Palette, PaletteEntries, TransparentGray, TransparentRed, TransparentGreen, TransparentBlue)
					end
				end
				local SwapRow = PreviousRow
				PreviousRow = CurrentRow
				CurrentRow = SwapRow
			end
		else
			for Pass = 1, 7 do
				local PassWidth = PassSize(Width, Adam7StartX[Pass], Adam7StepX[Pass])
				local PassHeight = PassSize(Height, Adam7StartY[Pass], Adam7StepY[Pass])
				if PassWidth > 0 and PassHeight > 0 then
					local RowBytes = math.floor((PassWidth * BitsPerPixel + 7) / 8)
					local CurrentRow = buffer.create(RowBytes)
					local PreviousRow = buffer.create(RowBytes)
					for PassY = 0, PassHeight - 1 do
						InflatedOffset = ReconstructRow(Inflated, InflatedOffset, CurrentRow, PreviousRow, RowBytes, FilterBpp)
						for PassX = 0, PassWidth - 1 do
							local X = Adam7StartX[Pass] + PassX * Adam7StepX[Pass]
							local Y = Adam7StartY[Pass] + PassY * Adam7StepY[Pass]
							WritePixel(Output, (Y * Width + X) * 4, CurrentRow, PassX, ColorType, BitDepth, Palette, PaletteEntries, TransparentGray, TransparentRed, TransparentGreen, TransparentBlue)
						end
						local SwapRow = PreviousRow
						PreviousRow = CurrentRow
						CurrentRow = SwapRow
					end
				end
			end
		end
		if InflatedOffset ~= buffer.len(Inflated) then
			error("PNG image data length mismatch")
		end
		return Output
	end

	local function ExpectedInflatedLength(Width: number, Height: number, BitsPerPixel: number, InterlaceMethod: number): number
		local Total = 0
		if InterlaceMethod == 0 then
			return Height * (math.floor((Width * BitsPerPixel + 7) / 8) + 1)
		end
		for Pass = 1, 7 do
			local PassWidth = PassSize(Width, Adam7StartX[Pass], Adam7StepX[Pass])
			local PassHeight = PassSize(Height, Adam7StartY[Pass], Adam7StepY[Pass])
			if PassWidth > 0 and PassHeight > 0 then
				Total = Total + PassHeight * (math.floor((PassWidth * BitsPerPixel + 7) / 8) + 1)
			end
		end
		return Total
	end

	local function StaticAdvanceFrame()
	end

	local function StaticReset()
	end

	local function AddFrameData(Frame: PngFrame, Offset: number, Count: number)
		if Count > MaxOutputBytes - Frame.DataLength then
			error("APNG frame data too large")
		end
		Frame.DataLength = Frame.DataLength + Count
		Frame.DataOffsets[#Frame.DataOffsets + 1] = Offset
		Frame.DataLengths[#Frame.DataLengths + 1] = Count
	end

	local function BuildChunkData(Source: buffer, Offsets: {[number]: number}, Lengths: {[number]: number}, TotalLength: number): buffer
		local Data = buffer.create(TotalLength)
		local DataOffset = 0
		for Index = 1, #Offsets do
			local SegmentLength = Lengths[Index]
			buffer.copy(Data, DataOffset, Source, Offsets[Index], SegmentLength)
			DataOffset = DataOffset + SegmentLength
		end
		return Data
	end

	local function DecodeFramePixels(PngData: buffer, Frame: PngFrame, ColorType: number, BitDepth: number, Channels: number, InterlaceMethod: number, Palette: buffer, PaletteEntries: number, TransparentGray: number, TransparentRed: number, TransparentGreen: number, TransparentBlue: number): buffer
		if Frame.DataLength <= 0 then
			error("missing APNG frame data")
		end
		local BitsPerPixel = Channels * BitDepth
		local ExpectedLength = ExpectedInflatedLength(Frame.Width, Frame.Height, BitsPerPixel, InterlaceMethod)
		if ExpectedLength > MaxOutputBytes then
			error("APNG frame data too large")
		end
		local Inflated = EmptyInflateData
		if #Frame.DataOffsets == 1 then
			Inflated = InflateZlibInternal(PngData, Frame.DataOffsets[1], Frame.DataLength, ExpectedLength, ExpectedLength)
		else
			local FrameData = BuildChunkData(PngData, Frame.DataOffsets, Frame.DataLengths, Frame.DataLength)
			Inflated = InflateZlib(FrameData, ExpectedLength)
		end
		return DecodePixels(Inflated, Frame.Width, Frame.Height, ColorType, BitDepth, Channels, InterlaceMethod, Palette, PaletteEntries, TransparentGray, TransparentRed, TransparentGreen, TransparentBlue)
	end

	local function DecodeAnimationFrames(PngData: buffer, Frames: {PngFrame}, StartIndex: number, ColorType: number, BitDepth: number, Channels: number, InterlaceMethod: number, Palette: buffer, PaletteEntries: number, TransparentGray: number, TransparentRed: number, TransparentGreen: number, TransparentBlue: number)
		for Index = StartIndex, #Frames do
			Frames[Index].Pixels = DecodeFramePixels(PngData, Frames[Index], ColorType, BitDepth, Channels, InterlaceMethod, Palette, PaletteEntries, TransparentGray, TransparentRed, TransparentGreen, TransparentBlue)
		end
	end

	local function ClearFrameArea(Canvas: buffer, CanvasWidth: number, XOffset: number, YOffset: number, Width: number, Height: number)
		if Width <= 0 or Height <= 0 then
			return
		end
		for Y = 0, Height - 1 do
			buffer.fill(Canvas, ((YOffset + Y) * CanvasWidth + XOffset) * 4, 0, Width * 4)
		end
	end

	local function SaveFrameArea(State: PngState, Frame: PngFrame)
		local RestoreBuffer = buffer.create(Frame.Width * Frame.Height * 4)
		for Y = 0, Frame.Height - 1 do
			buffer.copy(RestoreBuffer, Y * Frame.Width * 4, State.Canvas, ((Frame.YOffset + Y) * State.Width + Frame.XOffset) * 4, Frame.Width * 4)
		end
		State.RestoreBuffer = RestoreBuffer
		State.RestoreX = Frame.XOffset
		State.RestoreY = Frame.YOffset
		State.RestoreWidth = Frame.Width
		State.RestoreHeight = Frame.Height
	end

	local function RestoreFrameArea(State: PngState)
		local RestoreBuffer = State.RestoreBuffer
		if RestoreBuffer == nil then
			return
		end
		for Y = 0, State.RestoreHeight - 1 do
			buffer.copy(State.Canvas, ((State.RestoreY + Y) * State.Width + State.RestoreX) * 4, RestoreBuffer, Y * State.RestoreWidth * 4, State.RestoreWidth * 4)
		end
	end

	local function BlendPixel(Source: number, Destination: number): number
		local SourceAlpha = bit32.rshift(Source, 24)
		if SourceAlpha == 0 then
			return Destination
		elseif SourceAlpha == 255 then
			return Source
		end
		local DestinationAlpha = bit32.rshift(Destination, 24)
		if DestinationAlpha == 0 then
			return Source
		end
		local SourceRed = bit32.extract(Source, 0, 8)
		local SourceGreen = bit32.extract(Source, 8, 8)
		local SourceBlue = bit32.extract(Source, 16, 8)
		local DestinationRed = bit32.extract(Destination, 0, 8)
		local DestinationGreen = bit32.extract(Destination, 8, 8)
		local DestinationBlue = bit32.extract(Destination, 16, 8)
		local DestinationWeight = math.floor((DestinationAlpha * (255 - SourceAlpha) + 127) / 255)
		local OutputAlpha = SourceAlpha + DestinationWeight
		local Red = math.floor((SourceRed * SourceAlpha + DestinationRed * DestinationWeight + math.floor(OutputAlpha / 2)) / OutputAlpha)
		local Green = math.floor((SourceGreen * SourceAlpha + DestinationGreen * DestinationWeight + math.floor(OutputAlpha / 2)) / OutputAlpha)
		local Blue = math.floor((SourceBlue * SourceAlpha + DestinationBlue * DestinationWeight + math.floor(OutputAlpha / 2)) / OutputAlpha)
		return Red + Green * 256 + Blue * 65536 + OutputAlpha * 16777216
	end

	local function DrawAnimationFrame(State: PngState, Frame: PngFrame)
		if Frame.DisposeOp == 2 then
			SaveFrameArea(State, Frame)
		else
			State.RestoreBuffer = nil
			State.RestoreX = 0
			State.RestoreY = 0
			State.RestoreWidth = 0
			State.RestoreHeight = 0
		end
		local Pixels = Frame.Pixels
		if Frame.BlendOp == 0 then
			for Y = 0, Frame.Height - 1 do
				buffer.copy(State.Canvas, ((Frame.YOffset + Y) * State.Width + Frame.XOffset) * 4, Pixels, Y * Frame.Width * 4, Frame.Width * 4)
			end
		else
			for Y = 0, Frame.Height - 1 do
				local OutputOffset = ((Frame.YOffset + Y) * State.Width + Frame.XOffset) * 4
				local SourceOffset = Y * Frame.Width * 4
				for _ = 1, Frame.Width do
					buffer.writeu32(State.Canvas, OutputOffset, BlendPixel(buffer.readu32(Pixels, SourceOffset), buffer.readu32(State.Canvas, OutputOffset)))
					OutputOffset = OutputOffset + 4
					SourceOffset = SourceOffset + 4
				end
			end
		end
	end

	local function DisposeAnimationFrame(State: PngState, Frame: PngFrame)
		if Frame.DisposeOp == 1 then
			ClearFrameArea(State.Canvas, State.Width, Frame.XOffset, Frame.YOffset, Frame.Width, Frame.Height)
		elseif Frame.DisposeOp == 2 then
			RestoreFrameArea(State)
		end
		State.RestoreBuffer = nil
		State.RestoreX = 0
		State.RestoreY = 0
		State.RestoreWidth = 0
		State.RestoreHeight = 0
	end

	local function FrameDelay(Frame: PngFrame): number
		local Denominator = Frame.DelayDenominator
		if Denominator == 0 then
			Denominator = 100
		end
		return Frame.DelayNumerator / Denominator
	end

	local function SyncAnimationResult(State: PngState)
		local Result = State.Result
		if Result == nil then
			return
		end
		local Frame = State.Frames[State.CurrentFrameIndex]
		Result.Frame = State.Canvas
		Result.RGBA8 = State.Canvas
		Result.Delay = FrameDelay(Frame)
		Result.Finished = State.PlayCount > 0 and State.CurrentFrameIndex >= #State.Frames and State.CompletedPlays + 1 >= State.PlayCount
	end

	local function AdvancePngFrame(State: PngState)
		if State.CurrentFrameIndex >= #State.Frames then
			if State.PlayCount == 0 or State.CompletedPlays + 1 < State.PlayCount then
				DisposeAnimationFrame(State, State.Frames[State.CurrentFrameIndex])
				State.CompletedPlays = State.CompletedPlays + 1
				State.CurrentFrameIndex = 1
				DrawAnimationFrame(State, State.Frames[State.CurrentFrameIndex])
				SyncAnimationResult(State)
				return
			end
			SyncAnimationResult(State)
			return
		end
		DisposeAnimationFrame(State, State.Frames[State.CurrentFrameIndex])
		State.CurrentFrameIndex = State.CurrentFrameIndex + 1
		DrawAnimationFrame(State, State.Frames[State.CurrentFrameIndex])
		SyncAnimationResult(State)
	end

	local function ResetPngAnimation(State: PngState)
		buffer.fill(State.Canvas, 0, 0)
		State.CurrentFrameIndex = 1
		State.CompletedPlays = 0
		State.RestoreBuffer = nil
		State.RestoreX = 0
		State.RestoreY = 0
		State.RestoreWidth = 0
		State.RestoreHeight = 0
		DrawAnimationFrame(State, State.Frames[1])
		SyncAnimationResult(State)
	end

	-- Main DecodePng function
	local Length = buffer.len(PngData)
	if Length < 8 or buffer.readu8(PngData, 0) ~= PngSignature0 or buffer.readu8(PngData, 1) ~= PngSignature1 or buffer.readu8(PngData, 2) ~= PngSignature2 or buffer.readu8(PngData, 3) ~= PngSignature3 or buffer.readu8(PngData, 4) ~= PngSignature4 or buffer.readu8(PngData, 5) ~= PngSignature5 or buffer.readu8(PngData, 6) ~= PngSignature6 or buffer.readu8(PngData, 7) ~= PngSignature7 then
		error("missing PNG signature")
	end
	local Cursor = 8
	local Width = 0
	local Height = 0
	local BitDepth = 0
	local ColorType = 0
	local CompressionMethod = 0
	local FilterMethod = 0
	local InterlaceMethod = 0
	local Channels = 0
	local SawIHDR = false
	local SawPLTE = false
	local SawIDAT = false
	local SawTRNS = false
	local FinishedIDAT = false
	local SawIEND = false
	local SawSRGB = false
	local SawGAMA = false
	local SawCHRM = false
	local SawICCP = false
	local SawSBIT = false
	local SawBKGD = false
	local SawPHYS = false
	local SawHIST = false
	local SawTIME = false
	local SawCICP = false
	local SawEXIF = false
	local SawOFFS = false
	local SawGIFG = false
	local SawSTER = false
	local SawACTL = false
	local IdatLength = 0
	local ApngFrameCount = 0
	local ApngPlayCount = 0
	local NextApngSequence = 0
	local CurrentAnimationFrameIndex = 0
	local PaletteEntries = 0
	local TransparentGray = -1
	local TransparentRed = -1
	local TransparentGreen = -1
	local TransparentBlue = -1
	local Palette = buffer.create(1024)
	local IdatOffsets = {}
	local IdatLengths = {}
	local AnimationFrames = {}
	buffer.fill(Palette, 3, 255, 1021)
	while Cursor < Length do
		if Cursor + 12 > Length then
			error("truncated PNG chunk")
		end
		local ChunkLength = ReadU32BE(PngData, Cursor)
		local ChunkTypeOffset = Cursor + 4
		local ChunkType = ReadU32BE(PngData, ChunkTypeOffset)
		local ChunkDataOffset = Cursor + 8
		local ChunkCrcOffset = ChunkDataOffset + ChunkLength
		if ChunkLength > 0x7fffffff then
			error("invalid PNG chunk length")
		end
		if ChunkCrcOffset + 4 > Length then
			error("PNG chunk extends past data")
		end
		ValidateChunkName(PngData, ChunkTypeOffset)
		if Crc32(PngData, ChunkTypeOffset, ChunkDataOffset, ChunkLength) ~= ReadU32BE(PngData, ChunkCrcOffset) then
			error("invalid PNG chunk CRC")
		end
		if not SawIHDR and ChunkType ~= ChunkIHDR then
			error("PNG IHDR must be first")
		end
		if SawIDAT and ChunkType ~= ChunkIDAT then
			FinishedIDAT = true
		end
		if ChunkType == ChunkACTL then
			if not SawIHDR or SawACTL or SawIDAT or ChunkLength ~= 8 then
				error("invalid APNG acTL")
			end
			ApngFrameCount = ReadU32BE(PngData, ChunkDataOffset)
			ApngPlayCount = ReadU32BE(PngData, ChunkDataOffset + 4)
			if ApngFrameCount <= 0 then
				error("invalid APNG frame count")
			end
			SawACTL = true
		elseif ChunkType == ChunkFCTL then
			if not SawACTL or ChunkLength ~= 26 then
				error("invalid APNG fcTL")
			end
			if CurrentAnimationFrameIndex > 0 and AnimationFrames[CurrentAnimationFrameIndex].DataLength <= 0 then
				error("missing APNG frame data")
			end
			local SequenceNumber = ReadU32BE(PngData, ChunkDataOffset)
			if SequenceNumber ~= NextApngSequence then
				error("invalid APNG sequence number")
			end
			NextApngSequence = NextApngSequence + 1
			local FrameWidth = ReadU32BE(PngData, ChunkDataOffset + 4)
			local FrameHeight = ReadU32BE(PngData, ChunkDataOffset + 8)
			local XOffset = ReadU32BE(PngData, ChunkDataOffset + 12)
			local YOffset = ReadU32BE(PngData, ChunkDataOffset + 16)
			local DelayNumerator = ReadU16BE(PngData, ChunkDataOffset + 20)
			local DelayDenominator = ReadU16BE(PngData, ChunkDataOffset + 22)
			local DisposeOp = buffer.readu8(PngData, ChunkDataOffset + 24)
			local BlendOp = buffer.readu8(PngData, ChunkDataOffset + 25)
			if FrameWidth <= 0 or FrameHeight <= 0 or XOffset > Width or YOffset > Height or FrameWidth > Width - XOffset or FrameHeight > Height - YOffset or DisposeOp > 2 or BlendOp > 1 or FrameWidth > MaxOutputBytes / 4 / FrameHeight then
				error("invalid APNG frame control")
			end
			if not SawIDAT and #AnimationFrames == 0 and (FrameWidth ~= Width or FrameHeight ~= Height or XOffset ~= 0 or YOffset ~= 0) then
				error("invalid APNG default frame")
			end
			if #AnimationFrames >= ApngFrameCount then
				error("too many APNG frames")
			end
			AnimationFrames[#AnimationFrames + 1] = {
				Width = FrameWidth,
				Height = FrameHeight,
				XOffset = XOffset,
				YOffset = YOffset,
				DelayNumerator = DelayNumerator,
				DelayDenominator = DelayDenominator,
				DisposeOp = DisposeOp,
				BlendOp = BlendOp,
				DataOffsets = {},
				DataLengths = {},
				DataLength = 0,
				DataFromIdat = false,
				Pixels = EmptyInflateData,
			}
			CurrentAnimationFrameIndex = #AnimationFrames
		elseif ChunkType == ChunkFDAT then
			if not SawACTL or not SawIDAT or CurrentAnimationFrameIndex <= 0 or ChunkLength < 4 then
				error("invalid APNG fdAT")
			end
			if AnimationFrames[CurrentAnimationFrameIndex].DataFromIdat then
				error("invalid APNG fdAT")
			end
			local SequenceNumber = ReadU32BE(PngData, ChunkDataOffset)
			if SequenceNumber ~= NextApngSequence then
				error("invalid APNG sequence number")
			end
			NextApngSequence = NextApngSequence + 1
			AddFrameData(AnimationFrames[CurrentAnimationFrameIndex], ChunkDataOffset + 4, ChunkLength - 4)
		elseif ChunkType == ChunkIHDR then
			if SawIHDR or Cursor ~= 8 or ChunkLength ~= 13 then
				error("invalid PNG IHDR")
			end
			Width = ReadU32BE(PngData, ChunkDataOffset)
			Height = ReadU32BE(PngData, ChunkDataOffset + 4)
			BitDepth = buffer.readu8(PngData, ChunkDataOffset + 8)
			ColorType = buffer.readu8(PngData, ChunkDataOffset + 9)
			CompressionMethod = buffer.readu8(PngData, ChunkDataOffset + 10)
			FilterMethod = buffer.readu8(PngData, ChunkDataOffset + 11)
			InterlaceMethod = buffer.readu8(PngData, ChunkDataOffset + 12)
			if Width <= 0 or Height <= 0 or Width > MaxOutputBytes / 4 / Height then
				error("invalid PNG image dimensions")
			end
			if CompressionMethod ~= 0 or FilterMethod ~= 0 or (InterlaceMethod ~= 0 and InterlaceMethod ~= 1) then
				error("unsupported PNG header method")
			end
			Channels = ValidateColorType(ColorType, BitDepth)
			SawIHDR = true
		elseif ChunkType == ChunkPLTE then
			if not SawIHDR or SawPLTE or SawIDAT or ChunkLength % 3 ~= 0 or ChunkLength <= 0 or ChunkLength > 768 then
				error("invalid PNG PLTE")
			end
			PaletteEntries = math.floor(ChunkLength / 3)
			if ColorType == 0 or ColorType == 4 or (ColorType == 3 and PaletteEntries > BitPowers[BitDepth]) then
				error("invalid PNG PLTE for color type")
			end
			for Index = 0, PaletteEntries - 1 do
				local SourceOffset = ChunkDataOffset + Index * 3
				local PaletteOffset = Index * 4
				buffer.writeu8(Palette, PaletteOffset, buffer.readu8(PngData, SourceOffset))
				buffer.writeu8(Palette, PaletteOffset + 1, buffer.readu8(PngData, SourceOffset + 1))
				buffer.writeu8(Palette, PaletteOffset + 2, buffer.readu8(PngData, SourceOffset + 2))
				buffer.writeu8(Palette, PaletteOffset + 3, 255)
			end
			SawPLTE = true
		elseif ChunkType == ChunkTRNS then
			if not SawIHDR or SawTRNS or SawIDAT then
				error("invalid PNG tRNS order")
			end
			if ColorType == 0 then
				if ChunkLength ~= 2 then
					error("invalid grayscale PNG tRNS")
				end
				TransparentGray = ReadU16BE(PngData, ChunkDataOffset)
				if TransparentGray >= BitPowers[BitDepth] then
					error("invalid grayscale PNG tRNS value")
				end
			elseif ColorType == 2 then
				if ChunkLength ~= 6 then
					error("invalid RGB PNG tRNS")
				end
				TransparentRed = ReadU16BE(PngData, ChunkDataOffset)
				TransparentGreen = ReadU16BE(PngData, ChunkDataOffset + 2)
				TransparentBlue = ReadU16BE(PngData, ChunkDataOffset + 4)
				if BitDepth == 8 and (TransparentRed > 255 or TransparentGreen > 255 or TransparentBlue > 255) then
					error("invalid RGB PNG tRNS value")
				end
			elseif ColorType == 3 then
				if not SawPLTE or ChunkLength > PaletteEntries then
					error("invalid indexed PNG tRNS")
				end
				for Index = 0, ChunkLength - 1 do
					buffer.writeu8(Palette, Index * 4 + 3, buffer.readu8(PngData, ChunkDataOffset + Index))
				end
			else
				error("invalid PNG tRNS for color type")
			end
			SawTRNS = true
		elseif ChunkType == ChunkIDAT then
			if not SawIHDR or FinishedIDAT then
				error("invalid PNG IDAT order")
			end
			if ColorType == 3 and not SawPLTE then
				error("indexed PNG missing PLTE")
			end
			if ChunkLength > MaxOutputBytes - IdatLength then
				error("PNG IDAT data too large")
			end
			SawIDAT = true
			IdatLength = IdatLength + ChunkLength
			IdatOffsets[#IdatOffsets + 1] = ChunkDataOffset
			IdatLengths[#IdatLengths + 1] = ChunkLength
			if SawACTL and CurrentAnimationFrameIndex > 0 and #AnimationFrames == 1 then
				AddFrameData(AnimationFrames[CurrentAnimationFrameIndex], ChunkDataOffset, ChunkLength)
				AnimationFrames[CurrentAnimationFrameIndex].DataFromIdat = true
			end
		elseif ChunkType == ChunkIEND then
			if not SawIHDR or not SawIDAT or ChunkLength ~= 0 then
				error("invalid PNG IEND")
			end
			SawIEND = true
			Cursor = ChunkCrcOffset + 4
			break
		else
			if IsCriticalChunk(PngData, ChunkTypeOffset) then
				error("unsupported critical PNG chunk")
			end
		end
		Cursor = ChunkCrcOffset + 4
	end
	if not SawIEND or Cursor ~= Length then
		error("invalid PNG end")
	end
	if SawACTL then
		if #AnimationFrames ~= ApngFrameCount then
			error("invalid APNG frame count")
		end
		for Index = 1, #AnimationFrames do
			if AnimationFrames[Index].DataLength <= 0 then
				error("missing APNG frame data")
			end
		end
	end
	local BitsPerPixel = Channels * BitDepth
	local ExpectedLength = ExpectedInflatedLength(Width, Height, BitsPerPixel, InterlaceMethod)
	if ExpectedLength > MaxOutputBytes then
		error("PNG image data too large")
	end
	local Inflated = EmptyInflateData
	if #IdatOffsets == 1 then
		Inflated = InflateZlibInternal(PngData, IdatOffsets[1], IdatLength, ExpectedLength, ExpectedLength)
	else
		local IdatData = BuildChunkData(PngData, IdatOffsets, IdatLengths, IdatLength)
		Inflated = InflateZlib(IdatData, ExpectedLength)
	end
	local Output = DecodePixels(Inflated, Width, Height, ColorType, BitDepth, Channels, InterlaceMethod, Palette, PaletteEntries, TransparentGray, TransparentRed, TransparentGreen, TransparentBlue)
	if SawACTL then
		local AnimationDecodeStart = 1
		if AnimationFrames[1].DataFromIdat then
			AnimationFrames[1].Pixels = Output
			AnimationDecodeStart = 2
		end
		DecodeAnimationFrames(PngData, AnimationFrames, AnimationDecodeStart, ColorType, BitDepth, Channels, InterlaceMethod, Palette, PaletteEntries, TransparentGray, TransparentRed, TransparentGreen, TransparentBlue)
		local State = {
			Width = Width,
			Height = Height,
			Frames = AnimationFrames,
			PlayCount = ApngPlayCount,
			CompletedPlays = 0,
			Canvas = buffer.create(Width * Height * 4),
			CurrentFrameIndex = 1,
			RestoreBuffer = nil,
			RestoreX = 0,
			RestoreY = 0,
			RestoreWidth = 0,
			RestoreHeight = 0,
			Result = nil,
		}
		DrawAnimationFrame(State, AnimationFrames[1])
		local function AdvanceFrame()
			AdvancePngFrame(State)
		end
		local function Reset()
			ResetPngAnimation(State)
		end
		local Result = {
			Animated = true,
			Size = Vector2.new(Width, Height),
			RGBA8 = State.Canvas,
			Frame = State.Canvas,
			AdvanceFrame = AdvanceFrame,
			Reset = Reset,
			Finished = ApngPlayCount == 1 and #AnimationFrames <= 1,
			Delay = FrameDelay(AnimationFrames[1]),
		}
		State.Result = Result
		return Result
	end
	return {
		Animated = false,
		Size = Vector2.new(Width, Height),
		RGBA8 = Output,
		Frame = Output,
		AdvanceFrame = StaticAdvanceFrame,
		Reset = StaticReset,
		Finished = true,
		Delay = 0,
	}
end

-- Helper function to fetch and decode PNG images
local function fetchAndDecodePng(url: string): (boolean, buffer?, Vector2?)
	local HttpService = game:GetService("HttpService")
	local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
	
	if not requestFunction then
		return false, nil, nil
	end
	
	local success, result = pcall(function()
		return requestFunction({
			Url = url,
			Method = "GET"
		})
	end)
	
	if not success or not result then
		return false, nil, nil
	end
	
	local responseBody = result.Body or result.body or result
	if not responseBody then
		return false, nil, nil
	end
	
	-- Convert response to buffer
	local dataBuffer
	if type(responseBody) == "string" then
		dataBuffer = buffer.fromstring(responseBody)
	elseif type(responseBody) == "table" then
		-- Handle table response (some executors return tables)
		local str = ""
		for i = 1, #responseBody do
			str = str .. string.char(responseBody[i])
		end
		dataBuffer = buffer.fromstring(str)
	else
		return false, nil, nil
	end
	
	-- Decode PNG
	local decodeSuccess, decoded = pcall(function()
		return DecodePng(dataBuffer)
	end)
	
	if not decodeSuccess then
		return false, nil, nil
	end
	
	return true, decoded.RGBA8, decoded.Size
end

-- Cache for decoded images
local imageCache = {}

local function getDecodedImage(url: string): (boolean, buffer?, Vector2?)
	if imageCache[url] then
		return true, imageCache[url].data, imageCache[url].size
	end
	
	local success, data, size = fetchAndDecodePng(url)
	if success then
		imageCache[url] = { data = data, size = size }
	end
	
	return success, data, size
end

-- Early settings loading (before UI creation)
local SETTINGS_FILE = "prism/prism_settings.json"
if readfile then
    pcall(function()
        local data = readfile(SETTINGS_FILE)
        if data then
            local settings = game:GetService("HttpService"):JSONDecode(data)
            PM.autoExecutePrism = settings.autoExecutePrism or false
            PM.autoExecuteCommands = settings.autoExecuteCommands ~= false
            PM.terminalKeybind = settings.terminalKeybind or "F6"
        end
    end)
end

PM.mk = function(class, parent, props)
    local i = Instance.new(class)
    i.Parent = parent
    for k, v in pairs(props or {}) do i[k] = v end
    return i
end

PM.corner = function(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 6)
    c.Parent = p
    return c
end

PM.stroke = function(p, c, t, trans)
    local s = Instance.new("UIStroke")
    s.Color = c or Color3.fromRGB(40, 40, 40)
    s.Thickness = t or 1
    s.Transparency = trans or 0
    s.Parent = p
    return s
end

PM.tween = function(obj, time, props, style)
    return PM.Svc.TweenService:Create(obj, TweenInfo.new(time or 0.3, style or Enum.EasingStyle.Quad), props):Play()
end

PM.C = {
    bg = Color3.fromRGB(15, 15, 15),
    card = Color3.fromRGB(28, 28, 28),
    accent = Color3.fromRGB(180, 180, 180),
    text = Color3.fromRGB(230, 230, 230),
    textDim = Color3.fromRGB(90, 90, 90),
    border = Color3.fromRGB(45, 45, 45),
    green = Color3.fromRGB(70, 170, 70),
    red = Color3.fromRGB(170, 70, 70),
    sep = Color3.fromRGB(60, 60, 70),
}
local C = PM.C

-- Prism Nametag System Integration
local API_BASE_URL = "https://prismscript.vercel.app"
local API_ENDPOINT = API_BASE_URL .. "/api/nametags"

-- SPECIAL table: custom backgrounds per userId
local SPECIAL_CUSTOM_BGS = {
    [7275889224] = "https://prismscript.vercel.app/images/cat.jpg",
    -- Add more userId -> image URL mappings here
}

local nametagEnabled = true
local nametagGui = nil
local nametagConnection = nil
local otherNametags = {}
local autoSyncEnabled = true
local autoSyncInterval = 2

local function clearAllNametags()
    local player = PM.Svc.Players.LocalPlayer
    local playerGui = player:FindFirstChild("PlayerGui")
    
    -- Clear own nametag from PlayerGui
    if playerGui then
        for _, child in ipairs(playerGui:GetChildren()) do
            if child.Name == "PrismNametag" then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    -- Clear other players' nametags from PlayerGui
    if playerGui then
        for _, child in ipairs(playerGui:GetChildren()) do
            if child.Name:sub(1, 13) == "PrismNametag_" then
                pcall(function() child:Destroy() end)
            end
        end
    end
    
    -- Also clear from heads (cleanup from old version)
    if player.Character then
        local head = player.Character:FindFirstChild("Head")
        if head then
            for _, child in ipairs(head:GetChildren()) do
                if child.Name == "PrismNametag" then
                    pcall(function() child:Destroy() end)
                end
            end
        end
    end
    
    for _, plr in ipairs(PM.Svc.Players:GetPlayers()) do
        if plr.Character then
            local head = plr.Character:FindFirstChild("Head")
            if head then
                for _, child in ipairs(head:GetChildren()) do
                    if child.Name:sub(1, 13) == "PrismNametag_" then
                        pcall(function() child:Destroy() end)
                    end
                end
            end
        end
    end
    
    for userId, tagData in pairs(otherNametags) do
        if tagData.connection then
            tagData.connection:Disconnect()
        end
    end
    otherNametags = {}
    
    if nametagConnection then
        nametagConnection:Disconnect()
        nametagConnection = nil
    end
    nametagGui = nil
end

local function createNametag()
    local player = PM.Svc.Players.LocalPlayer
    if not player.Character then return end
    
    local head = player.Character:FindFirstChild("Head")
    if not head then return end
    
    if nametagGui then
        pcall(function() nametagGui:Destroy() end)
        nametagGui = nil
    end
    
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag" then
            pcall(function() child:Destroy() end)
        end
    end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrismNametag"
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 9999
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Parent = PM.Svc.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Background frame for border (fixes corner gaps) - added first to be behind
    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "BgFrame"
    bgFrame.Size = UDim2.new(1, 4, 1, 4)
    bgFrame.Position = UDim2.new(0, -2, 0, -2)
    bgFrame.BackgroundColor3 = C.sep
    bgFrame.BackgroundTransparency = 0
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = bgFrame
    
    local bgGradient = Instance.new("UIGradient")
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.25, C.sep),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(0.75, C.sep),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    bgGradient.Parent = bgFrame
    
    -- Check for custom background for local player
    local customBg = SPECIAL_CUSTOM_BGS[player.UserId]
    
    -- Custom background image if provided
    if customBg then
        local bgImage = Instance.new("ImageLabel")
        bgImage.Name = "CustomBg"
        bgImage.Size = UDim2.new(1, 0, 1, 0)
        bgImage.Position = UDim2.new(0, 0, 0, 0)
        bgImage.BackgroundTransparency = 1
        bgImage.ScaleType = Enum.ScaleType.Stretch
        bgImage.ZIndex = 0
        bgImage.Parent = bgFrame
        
        -- Try to fetch and decode PNG image
        local success, imageData, imageSize = getDecodedImage(customBg)
        if success and imageData then
            -- Convert RGBA8 buffer to base64 for display
            -- Note: This requires executor support for base64 image loading
            local base64Data = buffer.tobase64(imageData)
            if base64Data then
                -- Try using data URI format (executor-dependent)
                bgImage.Image = "data:image/png;base64," .. base64Data
            else
                -- Fallback to original URL
                bgImage.Image = customBg
            end
        else
            -- Fallback to original URL if decoding fails
            bgImage.Image = customBg
        end
        
        -- Hide gradient when using custom image
        bgGradient.Enabled = false
    end
    
    local frame = Instance.new("Frame")
    frame.Name = "TagFrame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = C.card
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Parent = billboard
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local displayNameLabel = Instance.new("TextLabel")
    displayNameLabel.Name = "DisplayName"
    displayNameLabel.Size = UDim2.new(1, -10, 0, 20)
    displayNameLabel.Position = UDim2.new(0, 5, 0, 5)
    displayNameLabel.BackgroundTransparency = 1
    displayNameLabel.Text = player.DisplayName
    displayNameLabel.TextColor3 = C.text
    displayNameLabel.TextSize = 14
    displayNameLabel.Font = Enum.Font.GothamBold
    displayNameLabel.TextXAlignment = Enum.TextXAlignment.Center
    displayNameLabel.Parent = frame
    
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "Username"
    usernameLabel.Size = UDim2.new(1, -10, 0, 16)
    usernameLabel.Position = UDim2.new(0, 5, 0, 25)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@ " .. player.Name
    usernameLabel.TextColor3 = C.textDim
    usernameLabel.TextSize = 11
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.Parent = frame
    
    local smallLabel = Instance.new("TextLabel")
    smallLabel.Name = "SmallLabel"
    smallLabel.Size = UDim2.new(1, 0, 1, 0)
    smallLabel.BackgroundTransparency = 1
    smallLabel.Text = "P"
    smallLabel.TextColor3 = C.text
    smallLabel.TextSize = 20
    smallLabel.Font = Enum.Font.GothamBold
    smallLabel.TextXAlignment = Enum.TextXAlignment.Center
    smallLabel.TextYAlignment = Enum.TextYAlignment.Center
    smallLabel.Visible = false
    smallLabel.Parent = frame
    
    nametagConnection = PM.Svc.RunService.Heartbeat:Connect(function(dt)
        if not billboard or not billboard.Parent then return end
        if bgGradient and bgGradient.Parent then
            bgGradient.Rotation = (bgGradient.Rotation + 120 * dt) % 360
        end
        
        -- Track head
        local currentHead = player.Character and player.Character:FindFirstChild("Head")
        if currentHead then
            billboard.Adornee = currentHead
        end
    end)
    
    nametagGui = billboard
end

local function removeNametag()
    if nametagConnection then
        nametagConnection:Disconnect()
        nametagConnection = nil
    end
    if nametagGui then
        pcall(function() nametagGui:Destroy() end)
        nametagGui = nil
    end
end

local function toggleNametag()
    nametagEnabled = not nametagEnabled
    if nametagEnabled then
        if nametagGui then
            nametagGui.Enabled = true
        else
            createNametag()
        end
        for userId, tagData in pairs(otherNametags) do
            if tagData.gui then
                tagData.gui.Enabled = true
            end
        end
    else
        if nametagGui then
            nametagGui.Enabled = false
        end
        for userId, tagData in pairs(otherNametags) do
            if tagData.gui then
                tagData.gui.Enabled = false
            end
        end
    end
    return nametagEnabled
end

local function createOtherNametag(plrObj)
    if not plrObj.Character then return end
    
    local head = plrObj.Character:FindFirstChild("Head")
    if not head then return end
    
    -- Check SPECIAL table for custom background
    local customBg = SPECIAL_CUSTOM_BGS[plrObj.UserId]
    
    if otherNametags[plrObj.UserId] then
        if otherNametags[plrObj.UserId].connection then
            otherNametags[plrObj.UserId].connection:Disconnect()
        end
        pcall(function() otherNametags[plrObj.UserId].gui:Destroy() end)
        otherNametags[plrObj.UserId] = nil
    end
    
    for _, child in ipairs(head:GetChildren()) do
        if child.Name == "PrismNametag_" .. plrObj.UserId then
            pcall(function() child:Destroy() end)
        end
    end
    
    local billboard = Instance.new("BillboardGui")
    billboard.Name = "PrismNametag_" .. plrObj.UserId
    billboard.Size = UDim2.new(0, 150, 0, 50)
    billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 9999
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Active = true
    billboard.Parent = PM.Svc.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "BgFrame"
    bgFrame.Size = UDim2.new(1, 4, 1, 4)
    bgFrame.Position = UDim2.new(0, -2, 0, -2)
    bgFrame.BackgroundColor3 = C.sep
    bgFrame.BackgroundTransparency = 0
    bgFrame.BorderSizePixel = 0
    bgFrame.Parent = billboard
    
    local bgCorner = Instance.new("UICorner")
    bgCorner.CornerRadius = UDim.new(0, 10)
    bgCorner.Parent = bgFrame
    
    local bgGradient = Instance.new("UIGradient")
    bgGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(0.25, C.sep),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(20, 20, 20)),
        ColorSequenceKeypoint.new(0.75, C.sep),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
    })
    bgGradient.Parent = bgFrame
    
    -- Custom background image if provided
    if customBg then
        local bgImage = Instance.new("ImageLabel")
        bgImage.Name = "CustomBg"
        bgImage.Size = UDim2.new(1, 0, 1, 0)
        bgImage.Position = UDim2.new(0, 0, 0, 0)
        bgImage.BackgroundTransparency = 1
        bgImage.ScaleType = Enum.ScaleType.Stretch
        bgImage.ZIndex = 0
        bgImage.Parent = bgFrame
        
        -- Try to fetch and decode PNG image
        local success, imageData, imageSize = getDecodedImage(customBg)
        if success and imageData then
            -- Convert RGBA8 buffer to base64 for display
            -- Note: This requires executor support for base64 image loading
            local base64Data = buffer.tobase64(imageData)
            if base64Data then
                -- Try using data URI format (executor-dependent)
                bgImage.Image = "data:image/png;base64," .. base64Data
            else
                -- Fallback to original URL
                bgImage.Image = customBg
            end
        else
            -- Fallback to original URL if decoding fails
            bgImage.Image = customBg
        end
        
        -- Hide gradient when using custom image
        bgGradient.Enabled = false
    end
    
    local frame = Instance.new("Frame")
    frame.Name = "TagFrame"
    frame.Size = UDim2.new(1, 0, 1, 0)
    frame.BackgroundColor3 = C.card
    frame.BackgroundTransparency = 0.1
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Parent = billboard
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame
    
    local displayNameLabel = Instance.new("TextLabel")
    displayNameLabel.Name = "DisplayName"
    displayNameLabel.Size = UDim2.new(1, -10, 0, 20)
    displayNameLabel.Position = UDim2.new(0, 5, 0, 5)
    displayNameLabel.BackgroundTransparency = 1
    displayNameLabel.Text = plrObj.DisplayName
    displayNameLabel.TextColor3 = C.text
    displayNameLabel.TextSize = 14
    displayNameLabel.Font = Enum.Font.GothamBold
    displayNameLabel.TextXAlignment = Enum.TextXAlignment.Center
    displayNameLabel.Parent = frame
    
    local usernameLabel = Instance.new("TextLabel")
    usernameLabel.Name = "Username"
    usernameLabel.Size = UDim2.new(1, -10, 0, 16)
    usernameLabel.Position = UDim2.new(0, 5, 0, 25)
    usernameLabel.BackgroundTransparency = 1
    usernameLabel.Text = "@ " .. plrObj.Name
    usernameLabel.TextColor3 = C.textDim
    usernameLabel.TextSize = 11
    usernameLabel.Font = Enum.Font.Gotham
    usernameLabel.TextXAlignment = Enum.TextXAlignment.Center
    usernameLabel.Parent = frame
    
    local smallLabel = Instance.new("TextLabel")
    smallLabel.Name = "SmallLabel"
    smallLabel.Size = UDim2.new(1, 0, 1, 0)
    smallLabel.BackgroundTransparency = 1
    smallLabel.Text = "P"
    smallLabel.TextColor3 = C.text
    smallLabel.TextSize = 20
    smallLabel.Font = Enum.Font.GothamBold
    smallLabel.TextXAlignment = Enum.TextXAlignment.Center
    smallLabel.TextYAlignment = Enum.TextYAlignment.Center
    smallLabel.Visible = false
    smallLabel.Parent = frame
    
    -- Click to teleport behind target
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            local myChar = PM.Svc.Players.LocalPlayer.Character
            local targetChar = plrObj.Character
            if myChar and myChar:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
                local myHRP = myChar.HumanoidRootPart
                local targetHRP = targetChar.HumanoidRootPart
                local behind = targetHRP.CFrame * CFrame.new(0, 0, 3)
                myHRP.CFrame = CFrame.new(behind.Position, behind.Position + targetHRP.CFrame.LookVector)
            end
        end
    end)
    
    local connection = PM.Svc.RunService.Heartbeat:Connect(function(dt)
        if not billboard or not billboard.Parent then return end
        if bgGradient and bgGradient.Parent then
            bgGradient.Rotation = (bgGradient.Rotation + 120 * dt) % 360
        end
        
        -- Track head
        local targetHead = plrObj.Character and plrObj.Character:FindFirstChild("Head")
        if targetHead then
            billboard.Adornee = targetHead
        end
        
        local myChar = PM.Svc.Players.LocalPlayer.Character
        local targetChar = plrObj.Character
        if myChar and myChar:FindFirstChild("HumanoidRootPart") and targetChar and targetChar:FindFirstChild("HumanoidRootPart") then
            local myHRP = myChar.HumanoidRootPart
            local targetHRP = targetChar.HumanoidRootPart
            local dist = (myHRP.Position - targetHRP.Position).Magnitude
            local isFar = dist > 50
            
            displayNameLabel.Visible = not isFar
            usernameLabel.Visible = not isFar
            smallLabel.Visible = isFar
            
            if isFar then
                PM.tween(billboard, 0.1, {Size = UDim2.new(0, 40, 0, 40)})
            else
                PM.tween(billboard, 0.1, {Size = UDim2.new(0, 150, 0, 50)})
            end
        end
    end)
    
    otherNametags[plrObj.UserId] = {
        gui = billboard,
        connection = connection
    }
end

local function removeOtherNametag(userId)
    if otherNametags[userId] then
        if otherNametags[userId].connection then
            otherNametags[userId].connection:Disconnect()
        end
        pcall(function() otherNametags[userId].gui:Destroy() end)
        otherNametags[userId] = nil
    end
end

local function readFromAPI()
    local HttpService = game:GetService("HttpService")
    local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        return nil
    end
    
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "GET"
    }
    
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        return nil
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess and responseData.success then
            return responseData.data
        end
    end
    
    return nil
end

local function updateOtherNametags()
    local data = readFromAPI()
    if not data or not data.users then return end
    
    local myJobId = game.JobId
    local myUserId = PM.Svc.Players.LocalPlayer.UserId
    
    local prismUsers = {}
    for _, user in ipairs(data.users) do
        if user.jobId == myJobId and tostring(user.userId) ~= tostring(myUserId) then
            prismUsers[user.userId] = user
        end
    end
    
    for userId, userData in pairs(prismUsers) do
        local plrObj = PM.Svc.Players:GetPlayerByUserId(tonumber(userId))
        if plrObj and not otherNametags[tonumber(userId)] then
            if plrObj.Character then
                createOtherNametag(plrObj)
            else
                plrObj.CharacterAdded:Connect(function(char)
                    task.wait(0.5)
                    if prismUsers[userId] and not otherNametags[tonumber(userId)] then
                        createOtherNametag(plrObj)
                    end
                end)
            end
        end
    end
    
    for userId, tagData in pairs(otherNametags) do
        if not prismUsers[tostring(userId)] then
            removeOtherNametag(userId)
        end
    end
end

local function getUserInfo()
    local player = PM.Svc.Players.LocalPlayer
    if not player then
        return nil
    end
    
    local jobId = game.JobId
    local userId = player.UserId
    local username = player.Name
    local displayName = player.DisplayName or username
    
    return {
        username = username,
        displayName = displayName,
        userId = tostring(userId),
        jobId = jobId ~= "" and jobId or "unknown"
    }
end

local function sendToAPI(userInfo)
    local HttpService = game:GetService("HttpService")
    local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        return false, "No HTTP function available"
    end
    
    local requestBody = HttpService:JSONEncode(userInfo)
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "POST",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = requestBody
    }
    
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        return false, result
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess then
            if responseData.success then
                return true, responseData
            else
                return false, responseData.error
            end
        else
            return false, "Parse error"
        end
    else
        return false, "No response"
    end
end

local function deleteFromAPI(userId)
    local HttpService = game:GetService("HttpService")
    local requestFunction = request or (HttpService and HttpService.request) or http_request or (fluxus and fluxus.request)
    
    if not requestFunction then
        return false, "No HTTP function available"
    end
    
    local requestBody = HttpService:JSONEncode({userId = tostring(userId)})
    local requestTable = {
        Url = API_ENDPOINT,
        Method = "DELETE",
        Headers = {
            ["Content-Type"] = "application/json"
        },
        Body = requestBody
    }
    
    local success, result = pcall(function()
        return requestFunction(requestTable)
    end)
    
    if not success then
        return false, result
    end
    
    local responseBody = result.Body or result.body or result
    
    if responseBody then
        local responseSuccess, responseData = pcall(function()
            return HttpService:JSONDecode(responseBody)
        end)
        
        if responseSuccess then
            if responseData.success then
                return true, responseData
            else
                return false, responseData.error
            end
        else
            return false, "Parse error"
        end
    else
        return false, "No response"
    end
end

local function sendNametagData()
    local userInfo = getUserInfo()
    if not userInfo then
        return
    end
    
    local success, result = sendToAPI(userInfo)
    
    if success then
        updateOtherNametags()
    end
end

local function startAutoSync()
    while autoSyncEnabled and PM.Svc.RunService.Heartbeat:Wait() do
        task.wait(autoSyncInterval)
        if autoSyncEnabled then
            sendNametagData()
        end
    end
end

PM.PrismNametags = {
    toggle = toggleNametag,
    create = createNametag,
    remove = removeNametag,
    isEnabled = function()
        return nametagEnabled
    end,
    cleanup = function()
        -- Stop auto-sync
        autoSyncEnabled = false
        
        -- Clear all nametags
        clearAllNametags()
        
        -- Disconnect heartbeat connections
        if nametagConnection then
            nametagConnection:Disconnect()
            nametagConnection = nil
        end
        
        for userId, tagData in pairs(otherNametags) do
            if tagData.connection then
                tagData.connection:Disconnect()
            end
        end
        otherNametags = {}
        
        -- Remove self from API
        local player = PM.Svc.Players.LocalPlayer
        if player then
            task.spawn(function()
                deleteFromAPI(player.UserId)
            end)
        end
        
        -- Reset flags
        nametagGui = nil
        nametagEnabled = false
    end
}

PM.createMainGUI = function()
    if PM.Svc.CoreGui:FindFirstChild("PrismMainGui") then return end
    
    PM.UI.Gui = PM.mk("ScreenGui", PM.Svc.CoreGui, {
        Name = "PrismMainGui",
        DisplayOrder = 1000,
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    })
    
    PM.UI.Main = PM.mk("Frame", PM.UI.Gui, {
        Name = "MainFrame",
        Size = UDim2.new(0, 460, 0, 56),
        Position = UDim2.new(0.5, -230, 0, -30),
        BackgroundColor3 = C.bg,
        BackgroundTransparency = 0.15,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })
    PM.corner(PM.UI.Main, 14)
    PM.stroke(PM.UI.Main, C.border, 1, 0.4)
    
    PM.UI.StatsFrame = PM.mk("Frame", PM.UI.Main, {
        Name = "StatsFrame",
        Size = UDim2.new(0, 75, 0, 44),
        Position = UDim2.new(0, 14, 0.5, -22),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })
    
    PM.UI.FPSLabelText = PM.mk("TextLabel", PM.UI.StatsFrame, {
        Name = "FPSLabelText",
        Size = UDim2.new(0, 35, 0, 14),
        Position = UDim2.new(0, 0, 0, 2),
        BackgroundTransparency = 1,
        Text = "FPS",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    PM.UI.FPSLabel = PM.mk("TextLabel", PM.UI.StatsFrame, {
        Name = "FPSLabel",
        Size = UDim2.new(0, 40, 0, 14),
        Position = UDim2.new(0, 35, 0, 2),
        BackgroundTransparency = 1,
        Text = " ",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })

    PM.UI.PingLabelText = PM.mk("TextLabel", PM.UI.StatsFrame, {
        Name = "PingLabelText",
        Size = UDim2.new(0, 35, 0, 14),
        Position = UDim2.new(0, 0, 0, 23),
        BackgroundTransparency = 1,
        Text = "PING",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    PM.UI.PingLabel = PM.mk("TextLabel", PM.UI.StatsFrame, {
        Name = "PingLabel",
        Size = UDim2.new(0, 40, 0, 14),
        Position = UDim2.new(0, 35, 0, 23),
        BackgroundTransparency = 1,
        Text = " ",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    })
    
    PM.UI.ButtonsFrame = PM.mk("Frame", PM.UI.Main, {
        Name = "ButtonsFrame",
        Size = UDim2.new(0, 220, 0, 36),
        Position = UDim2.new(0.5, -110, 0.5, -18),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })
    
    PM.UI.ButtonsList = PM.mk("UIListLayout", PM.UI.ButtonsFrame, {
        Padding = UDim.new(0, 8),
        FillDirection = Enum.FillDirection.Horizontal,
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
    })
    
    local buttonData = {
        {name = "Commands", layout = 1, image = "rbxassetid://132440478962916"},
        {name = "Terminal", layout = 3, image = "rbxassetid://73577105416536"},
        {name = "NameTags", layout = 5, image = "rbxassetid://99892550804409"},
        {name = "Join", layout = 7, image = "rbxassetid://84437305519060"},
        {name = "Servers", layout = 9, image = "rbxassetid://138470287250966"},
        {name = "Settings", layout = 11, image = "rbxassetid://101119408272746"},
    }
    
    PM.UI.Buttons = {}
    for i, btn in ipairs(buttonData) do
        local button = PM.mk("ImageButton", PM.UI.ButtonsFrame, {
            Name = "Btn_" .. btn.name,
            Size = UDim2.new(0, 32, 0, 28),
            BackgroundColor3 = Color3.fromRGB(20, 20, 26),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            AutoButtonColor = false,
            LayoutOrder = btn.layout,
            ZIndex = 10,
        })
        PM.corner(button, 3)
        
        local icon = PM.mk("ImageLabel", button, {
            Name = "Icon",
            Size = UDim2.new(0, 18, 0, 18),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            BackgroundTransparency = 1,
            Image = btn.image,
            ImageColor3 = Color3.fromRGB(255, 255, 255),
            ZIndex = 2,
        })
        
        PM.clickSoundEnabled = true
        PM.clickVolume = 0.75
        PM.clickSoundID = "94859356677805"
        PM.hoverSoundEnabled = true
        PM.hoverVolume = 0.75
        PM.hoverSoundID = "107511012621133"

        if not PM.UI.HoverSound then
            PM.UI.HoverSound = PM.mk("Sound", PM.UI.Gui, {
                SoundId = "rbxassetid://" .. PM.hoverSoundID,
                Volume = PM.hoverVolume,
            })
        end

        if not PM.UI.ClickSound then
            PM.UI.ClickSound = PM.mk("Sound", PM.UI.Gui, {
                SoundId = "rbxassetid://" .. PM.clickSoundID,
                Volume = PM.clickVolume,
            })
        end

        PM.playClickSound = function()
            if PM.clickSoundEnabled and PM.UI.ClickSound then
                pcall(function() PM.UI.ClickSound:Play() end)
            end
        end

        PM.playHoverSound = function()
            if PM.hoverSoundEnabled and PM.UI.HoverSound then
                pcall(function() PM.UI.HoverSound:Play() end)
            end
        end
        
        local isHovering = false
        button.MouseEnter:Connect(function()
            isHovering = true
            PM.isHoveringAnyButton = true
            PM.tween(icon, 0.15, {Size = UDim2.new(0, 22, 0, 22), ImageColor3 = Color3.fromRGB(180, 180, 190)})
            PM.playHoverSound()
        end)
        button.MouseLeave:Connect(function()
            isHovering = false
            PM.isHoveringAnyButton = false
            PM.tween(icon, 0.15, {Size = UDim2.new(0, 18, 0, 18), ImageColor3 = Color3.fromRGB(255, 255, 255)})
        end)
        button.MouseButton1Down:Connect(function()
            PM.tween(icon, 0.08, {Size = UDim2.new(0, 16, 0, 16)})
        end)
        button.MouseButton1Up:Connect(function()
            local targetSize = isHovering and UDim2.new(0, 22, 0, 22) or UDim2.new(0, 18, 0, 18)
            PM.tween(icon, 0.08, {Size = targetSize})
        end)
        if btn.name == "Terminal" then
            PM.isTerminalOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isTerminalOpen then
                    PM.isTerminalOpen = false
                    PM.hideTerminalPanel()
                else
                    PM.isTerminalOpen = true
                    if PM.isCommandsOpen then
                        PM.isCommandsOpen = false
                        PM.hideCommandsPanel()
                    end
                    if PM.isServersOpen then
                        PM.isServersOpen = false
                        PM.hideServersPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    if PM.isJoinOpen then
                        PM.isJoinOpen = false
                        PM.hideJoinPanel()
                    end
                    if PM.isSettingsOpen then
                        PM.isSettingsOpen = false
                        PM.hideSettingsPanel()
                    end
                    PM.toggleTerminalPanel()
                end
            end)
        elseif btn.name == "Commands" then
            PM.isCommandsOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isCommandsOpen then
                    PM.isCommandsOpen = false
                    PM.closeCommandsPanel()
                else
                    PM.isCommandsOpen = true
                    if PM.isTerminalOpen then
                        PM.isTerminalOpen = false
                        PM.hideTerminalPanel()
                    end
                    if PM.isServersOpen then
                        PM.isServersOpen = false
                        PM.hideServersPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    if PM.isJoinOpen then
                        PM.isJoinOpen = false
                        PM.hideJoinPanel()
                    end
                    if PM.isSettingsOpen then
                        PM.isSettingsOpen = false
                        PM.hideSettingsPanel()
                    end
                    PM.openCommandsPanel()
                end
            end)
        elseif btn.name == "NameTags" then
            PM.isNameTagsEnabled = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                PM.isNameTagsEnabled = PM.PrismNametags.toggle()
                if PM.isTerminalOpen then
                    PM.isTerminalOpen = false
                    PM.hideTerminalPanel()
                end
                if PM.isCommandsOpen then
                    PM.isCommandsOpen = false
                    PM.hideCommandsPanel()
                end
                if PM.isServersOpen then
                    PM.isServersOpen = false
                    PM.hideServersPanel()
                end
                if PM.isJoinOpen then
                    PM.isJoinOpen = false
                    PM.hideJoinPanel()
                end
                if PM.isSettingsOpen then
                    PM.isSettingsOpen = false
                    PM.hideSettingsPanel()
                end
                PM.toggleNameTagsPanel()
            end)
        elseif btn.name == "Servers" then
            PM.isServersOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isServersOpen then
                    PM.isServersOpen = false
                    PM.closeServersPanel()
                else
                    PM.isServersOpen = true
                    if PM.isTerminalOpen then
                        PM.isTerminalOpen = false
                        PM.hideTerminalPanel()
                    end
                    if PM.isCommandsOpen then
                        PM.isCommandsOpen = false
                        PM.hideCommandsPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    if PM.isJoinOpen then
                        PM.isJoinOpen = false
                        PM.hideJoinPanel()
                    end
                    if PM.isSettingsOpen then
                        PM.isSettingsOpen = false
                        PM.hideSettingsPanel()
                    end
                    PM.openServersPanel()
                end
            end)
        elseif btn.name == "Join" then
            PM.isJoinOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isJoinOpen then
                    PM.isJoinOpen = false
                    PM.closeJoinPanel()
                else
                    PM.isJoinOpen = true
                    if PM.isTerminalOpen then
                        PM.isTerminalOpen = false
                        PM.hideTerminalPanel()
                    end
                    if PM.isCommandsOpen then
                        PM.isCommandsOpen = false
                        PM.hideCommandsPanel()
                    end
                    if PM.isServersOpen then
                        PM.isServersOpen = false
                        PM.hideServersPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    if PM.isSettingsOpen then
                        PM.isSettingsOpen = false
                        PM.hideSettingsPanel()
                    end
                    PM.openJoinPanel()
                end
            end)
        elseif btn.name == "Settings" then
            PM.isSettingsOpen = false
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
                if PM.isSettingsOpen then
                    PM.isSettingsOpen = false
                    PM.closeSettingsPanel()
                else
                    PM.isSettingsOpen = true
                    if PM.isTerminalOpen then
                        PM.isTerminalOpen = false
                        PM.hideTerminalPanel()
                    end
                    if PM.isCommandsOpen then
                        PM.isCommandsOpen = false
                        PM.hideCommandsPanel()
                    end
                    if PM.isServersOpen then
                        PM.isServersOpen = false
                        PM.hideServersPanel()
                    end
                    if PM.isJoinOpen then
                        PM.isJoinOpen = false
                        PM.hideJoinPanel()
                    end
                    if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                        PM.UI.NameTagsPanel.Visible = false
                    end
                    PM.openSettingsPanel()
                end
            end)
        else
            button.MouseButton1Click:Connect(function()
                PM.playClickSound()
            end)
        end
        
        PM.UI.Buttons[btn.name] = button
    end
    
    PM.createTerminalPanel = function()
        if PM.UI.TerminalPanel then return end
        
        PM.UI.TerminalPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "TerminalPanel",
            Size = UDim2.new(0, 340, 0, 38),
            Position = UDim2.new(0.5, 0, 0, 35),
            AnchorPoint = Vector2.new(0.5, 0),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.18,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.TerminalPanel, 10)
        PM.stroke(PM.UI.TerminalPanel, C.border, 1, 0.5)
        
        -- Flag to prevent FocusLost from closing immediately after panel opens
        PM.panelJustOpened = false
        PM.keybindJustChanged = false
        
        PM.mk("TextLabel", PM.UI.TerminalPanel, {
            Size = UDim2.new(0, 24, 0, 38),
            Position = UDim2.new(0, 8, 0, 0),
            BackgroundTransparency = 1,
            Text = ">",
            TextColor3 = C.textDim,
            TextSize = 18,
            Font = Enum.Font.Gotham,
            ZIndex = 101,
        })
        
        PM.UI.TerminalAutofill = PM.mk("TextLabel", PM.UI.TerminalPanel, {
            Size = UDim2.new(1, -40, 0, 38),
            Position = UDim2.new(0, 32, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            TextColor3 = Color3.fromRGB(60, 60, 60), -- Darker than input text
            TextSize = 13,
            Font = Enum.Font.RobotoMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 102,
        })
        
        PM.UI.TerminalInput = PM.mk("TextBox", PM.UI.TerminalPanel, {
            Size = UDim2.new(1, -90, 0, 38),
            Position = UDim2.new(0, 32, 0, 0),
            BackgroundTransparency = 1,
            Text = "",
            PlaceholderText = "Enter a command...",
            PlaceholderColor3 = C.textDim,
            TextColor3 = C.textDim,
            TextSize = 13,
            Font = Enum.Font.RobotoMono,
            TextXAlignment = Enum.TextXAlignment.Left,
            ClearTextOnFocus = false,
            TextEditable = true,
            TextStrokeTransparency = 1,
            ZIndex = 105,
        })
        
        -- Keybind button (like Mono's F6 button in terminal)
        local keybindBtn = PM.mk("TextButton", PM.UI.TerminalPanel, {
            Name = "KeybindBtn",
            Size = UDim2.new(0, 46, 0, 22),
            Position = UDim2.new(1, -52, 0.5, 0),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.3,
            BorderSizePixel = 0,
            Text = PM.terminalKeybind or "F6",
            TextColor3 = C.textDim,
            TextSize = 10,
            Font = Enum.Font.GothamBold,
            ZIndex = 106,
        })
        PM.corner(keybindBtn, 4)
        
        -- Hover detection to prevent terminal close when rebinding
        PM.isHoveringKeybindBtn = false
        keybindBtn.MouseEnter:Connect(function()
            PM.isHoveringKeybindBtn = true
        end)
        keybindBtn.MouseLeave:Connect(function()
            PM.isHoveringKeybindBtn = false
        end)
        
        keybindBtn.MouseButton1Click:Connect(function()
            if PM.keybindJustChanged then
                PM.keybindJustChanged = false
                keybindBtn.Text = PM.terminalKeybind or "F6"
                keybindBtn.TextColor3 = C.textDim
            else
                PM.keybindJustChanged = true
                keybindBtn.Text = "..."
                keybindBtn.TextColor3 = C.textDim
            end
        end)
        
        -- Capture keybind from terminal panel
        game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if PM.keybindJustChanged and input.UserInputType == Enum.UserInputType.Keyboard then
                PM.keybindJustChanged = false
                PM.terminalKeybind = input.KeyCode.Name
                keybindBtn.Text = PM.terminalKeybind
                keybindBtn.TextColor3 = C.textDim
                -- Regain focus on input after rebinding
                task.delay(0.05, function()
                    if PM.UI.TerminalInput then
                        PM.UI.TerminalInput:CaptureFocus()
                    end
                end)
                -- Save to settings
                if writefile then
                    pcall(function()
                        local settings = {
                            autoExecutePrism = PM.autoExecutePrism or false,
                            autoExecuteCommands = PM.autoExecuteCommands ~= false,
                            terminalKeybind = PM.terminalKeybind,
                        }
                        writefile("prism/prism_settings.json", game:GetService("HttpService"):JSONEncode(settings))
                    end)
                end
            end
        end)
        
        -- Autofill functionality
        local function updateAutofill()
            local input = PM.UI.TerminalInput.Text:lower()
            if input == "" then
                PM.UI.TerminalAutofill.Text = ""
                return
            end
            
            -- Find first matching command
            for cmdName, cmd in pairs(PM.Commands or {}) do
                if cmdName:sub(1, #input) == input then
                    PM.UI.TerminalAutofill.Text = cmd.name
                    return
                end
                -- Check aliases too
                for _, alias in ipairs(cmd.aliases or {}) do
                    if alias:lower():sub(1, #input) == input then
                        PM.UI.TerminalAutofill.Text = cmd.name
                        return
                    end
                end
            end
            
            PM.UI.TerminalAutofill.Text = ""
        end
        
        PM.UI.TerminalInput:GetPropertyChangedSignal("Text"):Connect(updateAutofill)
        
        -- Handle Enter to execute and close
        PM.UI.TerminalInput.FocusLost:Connect(function(enterPressed)
            if enterPressed then
                local cmd = PM.UI.TerminalInput.Text
                local suggestion = PM.UI.TerminalAutofill.Text
                -- If there's an autofill suggestion, use it (like Mono)
                if suggestion and suggestion ~= "" and suggestion ~= " " then
                    cmd = suggestion
                end
                if cmd and cmd ~= "" then
                    PM.UI.TerminalInput.Text = ""
                    PM.UI.TerminalAutofill.Text = ""
                    if PM.executeCommand then
                        PM.executeCommand(cmd)
                    end
                end
                -- Close after executing command
                PM.isTerminalOpen = false
                PM.closeTerminalPanel()
            else
                -- Close on focus loss (clicking outside) - check blocking flags here
                if PM.panelJustOpened or PM.keybindJustChanged or PM.isHoveringKeybindBtn or PM.isHoveringAnyButton then
                    return
                end
                PM.isTerminalOpen = false
                PM.closeTerminalPanel()
            end
        end)
        
        -- Handle Tab for autofill and Escape to close
        game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if not PM.UI.TerminalPanel or not PM.UI.TerminalPanel.Visible then return end
            
            -- Skip keybind handling if panel just opened (prevents F6 from immediately closing)
            if PM.panelJustOpened then return end
            
            if input.KeyCode == Enum.KeyCode.Tab then
                local suggestion = PM.UI.TerminalAutofill.Text
                if suggestion and suggestion ~= "" then
                    PM.UI.TerminalInput.Text = suggestion
                    PM.UI.TerminalInput.CursorPosition = #suggestion + 1
                    PM.UI.TerminalAutofill.Text = ""
                end
            elseif input.KeyCode == Enum.KeyCode.Escape then
                PM.isTerminalOpen = false
                PM.closeTerminalPanel()
            end
        end)
        
    end
    
    PM.openTerminalPanel = function()
        if not PM.UI.TerminalPanel then
            PM.createTerminalPanel()
        end
        -- Keybind only opens, never closes (like Mono's bar)
        if PM.UI.TerminalPanel.Visible then return end
        
        -- Set flag to prevent immediate close
        PM.panelJustOpened = true
        task.delay(0.1, function()
            PM.panelJustOpened = false
        end)
        
        PM.isTerminalOpen = true
        PM.UI.TerminalPanel.Visible = true
        PM.UI.TerminalPanel.Size = UDim2.new(0, 0, 0, 38)
        PM.tween(PM.UI.TerminalPanel, 0.25, {Size = UDim2.new(0, 340, 0, 38)})
        PM.UI.TerminalInput:CaptureFocus()
    end
    
    -- For button toggle (opens and closes)
    PM.toggleTerminalPanel = function()
        if not PM.UI.TerminalPanel then
            PM.createTerminalPanel()
        end
        if PM.UI.TerminalPanel.Visible then
            PM.isTerminalOpen = false
            PM.closeTerminalPanel()
        else
            -- Set flag to prevent immediate close
            PM.panelJustOpened = true
            task.delay(0.1, function()
                PM.panelJustOpened = false
            end)
            
            PM.isTerminalOpen = true
            PM.UI.TerminalPanel.Visible = true
            PM.UI.TerminalPanel.Size = UDim2.new(0, 0, 0, 38)
            PM.tween(PM.UI.TerminalPanel, 0.25, {Size = UDim2.new(0, 340, 0, 38)})
            PM.UI.TerminalInput:CaptureFocus()
        end
    end
    
    PM.closeTerminalPanel = function()
        if not PM.UI.TerminalPanel or not PM.UI.TerminalPanel.Visible then return end
        
        PM.UI.TerminalInput:ReleaseFocus()
        PM.UI.TerminalInput.Text = ""
        PM.UI.TerminalAutofill.Text = ""
        PM.tween(PM.UI.TerminalPanel, 0.25, {Size = UDim2.new(0, 0, 0, 38)})
        task.delay(0.25, function()
            PM.UI.TerminalPanel.Visible = false
            PM.UI.TerminalPanel.Size = UDim2.new(0, 340, 0, 38)
        end)
    end
    
    PM.hideTerminalPanel = function()
        if not PM.UI.TerminalPanel then return end
        PM.UI.TerminalInput:ReleaseFocus()
        PM.UI.TerminalPanel.Visible = false
        PM.UI.TerminalPanel.Size = UDim2.new(0, 340, 0, 38)
    end

    PM.createCommandsPanel = function()
        if PM.UI.CommandsPanel then return end
        
        PM.UI.CommandsPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "CommandsPanel",
            Size = UDim2.new(0, 280, 0, 320),
            Position = UDim2.new(0.5, -140, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.CommandsPanel, 12)
        PM.stroke(PM.UI.CommandsPanel, C.border, 1, 0.4)
        
        PM.UI.CommandsTitle = PM.mk("TextLabel", PM.UI.CommandsPanel, {
            Size = UDim2.new(1, 0, 0, 36),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "Commands",
            TextColor3 = C.text,
            TextSize = 14,
            Font = Enum.Font.GothamBlack,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 101,
        })
        
        PM.UI.CommandsClose = PM.mk("TextButton", PM.UI.CommandsPanel, {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -30, 0, 6),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "X",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 101,
        })
        PM.corner(PM.UI.CommandsClose, 6)
        
        PM.UI.CommandsClose.MouseEnter:Connect(function()
            PM.UI.CommandsClose.TextColor3 = Color3.fromRGB(255, 80, 80)
        end)
        PM.UI.CommandsClose.MouseLeave:Connect(function()
            PM.UI.CommandsClose.TextColor3 = C.text
        end)
        
        PM.UI.CommandsClose.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.isCommandsOpen = false
            PM.UI.CommandsSearch.Text = ""
            PM.closeCommandsPanel()
        end)
        
        PM.UI.CommandsSearch = PM.mk("TextBox", PM.UI.CommandsPanel, {
            Name = "CommandsSearch",
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 38),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Text = "",
            PlaceholderText = "Search commands...",
            PlaceholderColor3 = C.textDim,
            TextColor3 = C.text,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = true,
            ZIndex = 101,
        })
        PM.corner(PM.UI.CommandsSearch, 6)
        
        PM.UI.CommandsScroll = PM.mk("ScrollingFrame", PM.UI.CommandsPanel, {
            Size = UDim2.new(1, -10, 1, -80),
            Position = UDim2.new(0, 9, 0, 70),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 101,
        })
        
        PM.UI.CommandsList = PM.mk("UIListLayout", PM.UI.CommandsScroll, {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.Name,
        })
        
        PM.UI.CommandsList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            PM.UI.CommandsScroll.CanvasSize = UDim2.new(0, 0, 0, PM.UI.CommandsList.AbsoluteContentSize.Y)
        end)
        
        PM.UI.CommandButtons = {}
        
        PM.UI.CommandsSearch:GetPropertyChangedSignal("Text"):Connect(function()
            local search = PM.UI.CommandsSearch.Text:lower()
            local visibleCount = 0
            for _, data in ipairs(PM.UI.CommandButtons) do
                local match = data.name:lower():find(search, 1, true) or data.desc:lower():find(search, 1, true)
                data.btn.Visible = match or search == ""
                if data.btn.Visible then visibleCount = visibleCount + 1 end
            end
            PM.UI.CommandsScroll.CanvasSize = UDim2.new(0, 0, 0, visibleCount * 38)
        end)
    end
    
    PM.openCommandsPanel = function()
        if not PM.UI.CommandsPanel then
            PM.createCommandsPanel()
        end
        if PM.UI.CommandsPanel.Visible then return end
        
        PM.UI.CommandsPanel.Visible = true
        PM.UI.CommandsPanel.Size = UDim2.new(0, 280, 0, 0)
        PM.tween(PM.UI.CommandsPanel, 0.3, {Size = UDim2.new(0, 280, 0, 320)})
    end
    
    PM.closeCommandsPanel = function()
        if not PM.UI.CommandsPanel or not PM.UI.CommandsPanel.Visible then return end
        
        PM.UI.CommandsSearch.Text = ""
        PM.tween(PM.UI.CommandsPanel, 0.3, {Size = UDim2.new(0, 280, 0, 0)})
        task.delay(0.3, function()
            PM.UI.CommandsPanel.Visible = false
            PM.UI.CommandsPanel.Size = UDim2.new(0, 280, 0, 320)
        end)
    end
    
    PM.hideCommandsPanel = function()
        if not PM.UI.CommandsPanel then return end
        PM.UI.CommandsSearch.Text = ""
        PM.UI.CommandsPanel.Visible = false
        PM.UI.CommandsPanel.Size = UDim2.new(0, 280, 0, 320)
    end

    PM.createNameTagsPanel = function()
        if PM.UI.NameTagsPanel then return end
        
        PM.UI.NameTagsPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "NameTagsPanel",
            Size = UDim2.new(0, 120, 0, 26),
            Position = UDim2.new(0.5, -60, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
        })
        PM.corner(PM.UI.NameTagsPanel, 6)
        PM.stroke(PM.UI.NameTagsPanel, C.border, 1, 1)
        
        PM.UI.NameTagsLabel = PM.mk("TextLabel", PM.UI.NameTagsPanel, {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "Nametags On",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBlack,
            TextXAlignment = Enum.TextXAlignment.Center,
            TextTransparency = 1,
            ZIndex = 101,
        })
    end
    
    PM.toggleNameTagsPanel = function()
        if not PM.UI.NameTagsPanel then
            PM.createNameTagsPanel()
        end
        
        if PM.isNameTagsEnabled then
            PM.UI.NameTagsLabel.Text = "Nametags On"
        else
            PM.UI.NameTagsLabel.Text = "Nametags Off"
        end
        
        if PM.fadeOutTask then
            task.cancel(PM.fadeOutTask)
        end
        
        if not PM.UI.NameTagsPanel.Visible then
            PM.UI.NameTagsPanel.Visible = true
            PM.UI.NameTagsPanel.BackgroundTransparency = 1
            PM.UI.NameTagsLabel.TextTransparency = 1
            PM.UI.NameTagsPanel.UIStroke.Transparency = 1
            
            PM.tween(PM.UI.NameTagsPanel, 0.2, {BackgroundTransparency = 0.15})
            PM.tween(PM.UI.NameTagsPanel.UIStroke, 0.2, {Transparency = 0.4})
            PM.tween(PM.UI.NameTagsLabel, 0.2, {TextTransparency = 0})
        end
        
        PM.fadeOutTask = task.delay(1.5, function()
            PM.tween(PM.UI.NameTagsLabel, 0.3, {TextTransparency = 1})
            PM.tween(PM.UI.NameTagsPanel, 0.3, {BackgroundTransparency = 1})
            PM.tween(PM.UI.NameTagsPanel.UIStroke, 0.3, {Transparency = 1})
            task.delay(0.3, function()
                PM.UI.NameTagsPanel.Visible = false
            end)
        end)
    end

    PM.createServersPanel = function()
        if PM.UI.ServersPanel then return end
        
        PM.UI.ServersPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "ServersPanel",
            Size = UDim2.new(0, 280, 0, 0),
            Position = UDim2.new(0.5, -140, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.ServersPanel, 12)
        PM.stroke(PM.UI.ServersPanel, C.border, 1, 0.4)
        
        PM.UI.ServersTitle = PM.mk("TextLabel", PM.UI.ServersPanel, {
            Size = UDim2.new(1, 0, 0, 36),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "Servers",
            TextColor3 = C.text,
            TextSize = 14,
            Font = Enum.Font.GothamBlack,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 101,
        })
        
        PM.UI.ServersClose = PM.mk("TextButton", PM.UI.ServersPanel, {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -30, 0, 6),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "X",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 101,
        })
        PM.corner(PM.UI.ServersClose, 6)
        
        PM.UI.ServersClose.MouseEnter:Connect(function()
            PM.UI.ServersClose.TextColor3 = Color3.fromRGB(255, 80, 80)
        end)
        PM.UI.ServersClose.MouseLeave:Connect(function()
            PM.UI.ServersClose.TextColor3 = C.text
        end)
        
        PM.UI.ServersClose.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.isServersOpen = false
            PM.closeServersPanel()
        end)
        
        PM.UI.ServersFilterFrame = PM.mk("Frame", PM.UI.ServersPanel, {
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 38),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 101,
        })
        PM.corner(PM.UI.ServersFilterFrame, 6)
        
        PM.UI.ServersFilterList = PM.mk("UIListLayout", PM.UI.ServersFilterFrame, {
            Padding = UDim.new(0, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        
        -- Exclude Full Servers Background
        PM.UI.ExcludeFullBg = PM.mk("Frame", PM.UI.ServersPanel, {
            Size = UDim2.new(1, -16, 0, 26),
            Position = UDim2.new(0, 8, 0, 70),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 100,
        })
        PM.corner(PM.UI.ExcludeFullBg, 6)
        
        -- Exclude Full Servers Label
        PM.UI.ExcludeFullLabel = PM.mk("TextLabel", PM.UI.ServersPanel, {
            Size = UDim2.new(1, -56, 0, 20),
            Position = UDim2.new(0, 13, 0, 72),
            BackgroundTransparency = 1,
            Text = "Exclude full servers",
            TextColor3 = C.text,
            TextSize = 10,
            Font = Enum.Font.Gotham,
            TextXAlignment = Enum.TextXAlignment.Left,
            ZIndex = 101,
        })
        
        -- Toggle Switch (Mono.lua style)
        PM.UI.ExcludeFullSwitch = PM.mk("Frame", PM.UI.ServersPanel, {
            Size = UDim2.new(0, 26, 0, 13),
            Position = UDim2.new(1, -39, 0, 81),
            AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = Color3.fromRGB(50, 50, 50),
            BorderSizePixel = 0,
            ZIndex = 101,
        })
        PM.corner(PM.UI.ExcludeFullSwitch, 10)
        
        -- Toggle Circle
        PM.UI.ExcludeFullCircle = PM.mk("Frame", PM.UI.ExcludeFullSwitch, {
            Size = UDim2.new(0, 9, 0, 9),
            Position = UDim2.new(0, 2, 0.5, -4),
            BackgroundColor3 = Color3.fromRGB(235, 235, 235),
            BorderSizePixel = 0,
            ZIndex = 102,
        })
        PM.corner(PM.UI.ExcludeFullCircle, 10)
        
        -- Toggle Hit Button
        PM.UI.ExcludeFullToggle = PM.mk("TextButton", PM.UI.ExcludeFullSwitch, {
            Size = UDim2.new(1, 0, 1, 0),
            BackgroundTransparency = 1,
            Text = "",
            ZIndex = 103,
        })
        
        -- Set initial visual state (ON by default with medium gray)
        PM.UI.ExcludeFullSwitch.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        PM.UI.ExcludeFullCircle.Position = UDim2.new(1, -11, 0.5, -4)
        
        PM.UI.ExcludeFullToggle.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.excludeFullServers = not PM.excludeFullServers
            if PM.excludeFullServers then
                PM.tween(PM.UI.ExcludeFullSwitch, 0.2, {BackgroundColor3 = Color3.fromRGB(80, 80, 80)})
                PM.tween(PM.UI.ExcludeFullCircle, 0.2, {Position = UDim2.new(1, -11, 0.5, -4)})
            else
                PM.tween(PM.UI.ExcludeFullSwitch, 0.2, {BackgroundColor3 = Color3.fromRGB(50, 50, 50)})
                PM.tween(PM.UI.ExcludeFullCircle, 0.2, {Position = UDim2.new(0, 2, 0.5, -4)})
            end
            PM.serversFetched = false
            PM.fetchServers()
        end)
        
        PM.serversFilter = "most"
        PM.excludeFullServers = true
        PM.serverListData = {}
        PM.serversFetched = false
        
        local filters = {
            {name = "Most", id = "most", order = 1},
            {name = "Low Ping", id = "lowping", order = 2},
            {name = "Fewest", id = "fewest", order = 3},
        }
        
        PM.UI.ServersFilterButtons = {}
        for _, filter in ipairs(filters) do
            local btn = PM.mk("TextButton", PM.UI.ServersFilterFrame, {
                Size = UDim2.new(0, 80, 0, 24),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = filter.id == "most" and 0.3 or 0.7,
                BorderSizePixel = 0,
                Text = filter.name,
                TextColor3 = C.text,
                TextSize = 9,
                Font = Enum.Font.Gotham,
                Name = filter.id,
                LayoutOrder = filter.order,
                ZIndex = 102,
            })
            PM.corner(btn, 4)
            
            btn.MouseButton1Click:Connect(function()
                PM.playClickSound()
                PM.serversFilter = filter.id
                for _, b in ipairs(PM.UI.ServersFilterButtons) do
                    PM.tween(b, 0.15, {BackgroundTransparency = b.Name == filter.id and 0.3 or 0.7})
                end
                PM.renderServerList()
            end)
            
            table.insert(PM.UI.ServersFilterButtons, btn)
        end
        
        PM.UI.ServersScroll = PM.mk("ScrollingFrame", PM.UI.ServersPanel, {
            Size = UDim2.new(1, -10, 1, -110),
            Position = UDim2.new(0, 9, 0, 100),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 101,
        })
        
        PM.UI.ServersList = PM.mk("UIListLayout", PM.UI.ServersScroll, {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.Name,
        })
        
        PM.UI.ServersList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            PM.UI.ServersScroll.CanvasSize = UDim2.new(0, 0, 0, PM.UI.ServersList.AbsoluteContentSize.Y)
        end)
        
    end
    
    PM.fetchServers = function()
        local HttpService = game:GetService("HttpService")
        local success, result = pcall(function()
            return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
        end)
        
        if success and result and result.data then
            PM.serverListData = {}
            for _, server in ipairs(result.data) do
                if not PM.excludeFullServers or server.playing < server.maxPlayers then
                    table.insert(PM.serverListData, server)
                end
            end
            PM.serversFetched = true
            PM.renderServerList()
            return true
        else
            return false
        end
    end
    
    PM.renderServerList = function()
        if not PM.UI.ServersScroll then return end
        
        for _, child in ipairs(PM.UI.ServersScroll:GetChildren()) do
            if child:IsA("TextButton") then
                child:Destroy()
            end
        end
        
        local servers = {}
        for _, server in ipairs(PM.serverListData) do
            table.insert(servers, server)
        end
        
        if PM.serversFilter == "lowping" then
            table.sort(servers, function(a, b)
                return (a.ping or math.huge) < (b.ping or math.huge)
            end)
        elseif PM.serversFilter == "most" then
            table.sort(servers, function(a, b)
                return (a.playing or 0) > (b.playing or 0)
            end)
        elseif PM.serversFilter == "fewest" then
            table.sort(servers, function(a, b)
                return (a.playing or 0) < (b.playing or 0)
            end)
        end
        
        local displayCount = math.min(#servers, 25)
        for i = 1, displayCount do
            local server = servers[i]
            if not server then break end
            
            local ping = server.ping or 0
            local playing = server.playing or 0
            local maxPlayers = server.maxPlayers or 0
            local pingColor = ping < 50 and Color3.fromRGB(80, 220, 120) or ping < 100 and Color3.fromRGB(255, 200, 80) or Color3.fromRGB(255, 80, 80)
            
            local btn = PM.mk("TextButton", PM.UI.ServersScroll, {
                Size = UDim2.new(1, -6, 0, 32),
                BackgroundColor3 = C.card,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                Text = "",
                Name = "Server_" .. i,
                ZIndex = 102,
            })
            PM.corner(btn, 6)
            
            PM.mk("TextLabel", btn, {
                Size = UDim2.new(0.4, 0, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = "Ping: " .. ping .. "ms",
                TextColor3 = pingColor,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 103,
            })
            
            PM.mk("TextLabel", btn, {
                Size = UDim2.new(0.5, 0, 1, 0),
                Position = UDim2.new(0.5, -8, 0, 0),
                BackgroundTransparency = 1,
                Text = playing .. "/" .. maxPlayers .. " players",
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 103,
            })
            
            btn.MouseEnter:Connect(function()
                PM.tween(btn, 0.15, {BackgroundTransparency = 0.2})
            end)
            btn.MouseLeave:Connect(function()
                PM.tween(btn, 0.15, {BackgroundTransparency = 0.5})
            end)
            btn.MouseButton1Click:Connect(function()
                PM.playClickSound()
                game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, server.id, PM.Svc.Players.LocalPlayer)
            end)
        end
        
    end
    
    PM.openServersPanel = function()
        if not PM.UI.ServersPanel then
            PM.createServersPanel()
        end
        
        PM.isServersOpen = true
        PM.UI.ServersPanel.Visible = true
        PM.UI.ServersPanel.Size = UDim2.new(0, 280, 0, 0)
        PM.tween(PM.UI.ServersPanel, 0.3, {Size = UDim2.new(0, 280, 0, 320)})
        
        if not PM.serversFetched then
            task.spawn(function()
                PM.fetchServers()
            end)
        end
    end
    
    PM.closeServersPanel = function()
        if not PM.UI.ServersPanel or not PM.UI.ServersPanel.Visible then return end
        
        PM.isServersOpen = false
        PM.tween(PM.UI.ServersPanel, 0.3, {Size = UDim2.new(0, 280, 0, 0)})
        task.delay(0.3, function()
            PM.UI.ServersPanel.Visible = false
            PM.UI.ServersPanel.Size = UDim2.new(0, 280, 0, 320)
        end)
    end
    
    PM.hideServersPanel = function()
        if not PM.UI.ServersPanel then return end
        PM.isServersOpen = false
        PM.UI.ServersPanel.Visible = false
        PM.UI.ServersPanel.Size = UDim2.new(0, 280, 0, 320)
    end
    
    -- ========== JOIN PRISM USERS PANEL ==========
    PM.createJoinPanel = function()
        if PM.UI.JoinPanel then return end
        
        PM.UI.JoinPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "JoinPanel",
            Size = UDim2.new(0, 280, 0, 0),
            Position = UDim2.new(0.5, -140, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.JoinPanel, 12)
        PM.stroke(PM.UI.JoinPanel, C.border, 1, 0.4)
        
        -- Title
        PM.UI.JoinTitle = PM.mk("TextLabel", PM.UI.JoinPanel, {
            Size = UDim2.new(1, 0, 0, 36),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "Join Prism Users",
            TextColor3 = C.text,
            TextSize = 14,
            Font = Enum.Font.GothamBlack,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 101,
        })
        
        -- Close button
        PM.UI.JoinClose = PM.mk("TextButton", PM.UI.JoinPanel, {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -30, 0, 6),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "X",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 101,
        })
        PM.corner(PM.UI.JoinClose, 6)
        
        PM.UI.JoinClose.MouseEnter:Connect(function()
            PM.UI.JoinClose.TextColor3 = Color3.fromRGB(255, 80, 80)
        end)
        PM.UI.JoinClose.MouseLeave:Connect(function()
            PM.UI.JoinClose.TextColor3 = C.text
        end)
        
        PM.UI.JoinClose.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.isJoinOpen = false
            PM.closeJoinPanel()
        end)
        
        -- Filter buttons frame
        PM.UI.JoinFilterFrame = PM.mk("Frame", PM.UI.JoinPanel, {
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 38),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 101,
        })
        PM.corner(PM.UI.JoinFilterFrame, 6)
        
        local filterList = PM.mk("UIListLayout", PM.UI.JoinFilterFrame, {
            Padding = UDim.new(0, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
        })
        
        -- Filter buttons
        PM.UI.JoinFilterButtons = {}
        local filters = {
            {name = "This Game", id = "This Game"},
            {name = "All Games", id = "All Games"},
            {name = "Friends", id = "Friends"},
        }
        for _, filter in ipairs(filters) do
            local btn = PM.mk("TextButton", PM.UI.JoinFilterFrame, {
                Name = filter.id,
                Size = UDim2.new(0, 76, 0, 24),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = filter.id == "All Games" and 0.3 or 0.7,
                BorderSizePixel = 0,
                Text = filter.name,
                TextColor3 = C.text,
                TextSize = 9,
                Font = Enum.Font.Gotham,
                ZIndex = 102,
            })
            PM.corner(btn, 4)
            table.insert(PM.UI.JoinFilterButtons, btn)
        end
        
        -- Search box
        PM.UI.JoinSearch = PM.mk("TextBox", PM.UI.JoinPanel, {
            Name = "JoinSearch",
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 70),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            Text = "",
            PlaceholderText = "Search users...",
            TextColor3 = C.text,
            PlaceholderColor3 = Color3.fromRGB(120, 120, 120),
            TextSize = 10,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = false,
            ZIndex = 101,
        })
        PM.corner(PM.UI.JoinSearch, 6)
        
        -- User scroll frame (no refresh button, so larger)
        PM.UI.JoinScroll = PM.mk("ScrollingFrame", PM.UI.JoinPanel, {
            Name = "JoinScroll",
            Size = UDim2.new(1, -10, 1, -106),
            Position = UDim2.new(0, 9, 0, 102),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 101,
        })
        
        PM.UI.JoinList = PM.mk("UIListLayout", PM.UI.JoinScroll, {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })
        
        PM.UI.JoinList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            PM.UI.JoinScroll.CanvasSize = UDim2.new(0, 0, 0, PM.UI.JoinList.AbsoluteContentSize.Y)
        end)
        
        -- Join panel logic
        local HttpService = game:GetService("HttpService")
        local TeleportService = game:GetService("TeleportService")
        local currentJoinFilter = "All Games"
        local cachedServers = {}
        local renderServerList
        
        local function fetchPrismServers()
            local servers = PM.PrismAPI.getServers(true)
            return servers or {}
        end
        
        renderServerList = function()
            -- Clear existing
            for _, child in ipairs(PM.UI.JoinScroll:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
            
            local servers = cachedServers
            local searchQuery = PM.UI.JoinSearch.Text:lower()
            
            for _, server in ipairs(servers) do
                -- Filter by search
                if searchQuery ~= "" then
                    local usernames = server.usernames or {}
                    local match = false
                    for _, username in ipairs(usernames) do
                        if username:lower():find(searchQuery, 1, true) then
                            match = true
                            break
                        end
                    end
                    if not match then continue end
                end
                
                local userCount = server.user_count or 0
                local usernames = server.usernames or {}
                local usernameList = table.concat(usernames, ", ")
                
                local btn = PM.mk("TextButton", PM.UI.JoinScroll, {
                    Size = UDim2.new(1, -6, 0, 44),
                    BackgroundColor3 = C.card,
                    BackgroundTransparency = 0.5,
                    BorderSizePixel = 0,
                    Text = "",
                    Name = "Server_" .. tostring(server.server_id),
                    ZIndex = 102,
                })
                PM.corner(btn, 6)
                
                PM.mk("TextLabel", btn, {
                    Size = UDim2.new(1, -16, 0, 16),
                    Position = UDim2.new(0, 8, 0, 4),
                    BackgroundTransparency = 1,
                    Text = userCount .. " Prism User(s)",
                    TextColor3 = Color3.fromRGB(0, 200, 70),
                    TextSize = 11,
                    Font = Enum.Font.GothamBold,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 103,
                })
                
                PM.mk("TextLabel", btn, {
                    Size = UDim2.new(1, -16, 0, 24),
                    Position = UDim2.new(0, 8, 0, 20),
                    BackgroundTransparency = 1,
                    Text = usernameList,
                    TextColor3 = C.textDim,
                    TextSize = 9,
                    Font = Enum.Font.Gotham,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    TextWrapped = true,
                    ZIndex = 103,
                })
                
                btn.MouseEnter:Connect(function()
                    PM.tween(btn, 0.15, {BackgroundTransparency = 0.2})
                end)
                btn.MouseLeave:Connect(function()
                    PM.tween(btn, 0.15, {BackgroundTransparency = 0.5})
                end)
                btn.MouseButton1Click:Connect(function()
                    PM.playClickSound()
                    pcall(function()
                        TeleportService:TeleportToPlaceInstance(game.PlaceId, server.server_id, PM.Svc.Players.LocalPlayer)
                    end)
                end)
            end
        end
        
        -- Initial fetch
        cachedServers = fetchPrismServers()
        renderServerList()
        
        -- Refresh every 30 seconds
        spawn(function()
            while PM.UI.JoinPanel do
                task.wait(30)
                cachedServers = fetchPrismServers()
                renderServerList()
            end
        end)
        
        -- Search filter
        PM.UI.JoinSearch:GetPropertyChangedSignal("Text"):Connect(function()
            renderServerList()
        end)
        
        -- Filter buttons
        for _, btn in ipairs(PM.UI.JoinFilterButtons) do
            btn.MouseButton1Click:Connect(function()
                PM.playClickSound()
                currentJoinFilter = btn.Name
                for _, b in ipairs(PM.UI.JoinFilterButtons) do
                    PM.tween(b, 0.15, {BackgroundTransparency = b.Name == currentJoinFilter and 0.3 or 0.7})
                end
            end)
        end
    end
    
    PM.openJoinPanel = function()
        if not PM.UI.JoinPanel then
            PM.createJoinPanel()
        end
        
        PM.isJoinOpen = true
        PM.UI.JoinPanel.Visible = true
        PM.UI.JoinPanel.Size = UDim2.new(0, 280, 0, 0)
        PM.tween(PM.UI.JoinPanel, 0.3, {Size = UDim2.new(0, 280, 0, 320)})
    end
    
    PM.closeJoinPanel = function()
        if not PM.UI.JoinPanel or not PM.UI.JoinPanel.Visible then return end
        
        PM.isJoinOpen = false
        PM.tween(PM.UI.JoinPanel, 0.3, {Size = UDim2.new(0, 280, 0, 0)})
        task.delay(0.3, function()
            PM.UI.JoinPanel.Visible = false
            PM.UI.JoinPanel.Size = UDim2.new(0, 280, 0, 320)
        end)
    end
    
    PM.hideJoinPanel = function()
        if not PM.UI.JoinPanel then return end
        PM.isJoinOpen = false
        PM.UI.JoinPanel.Visible = false
        PM.UI.JoinPanel.Size = UDim2.new(0, 280, 0, 320)
    end

    PM.createSettingsPanel = function()
        if PM.UI.SettingsPanel then return end

        PM.UI.SettingsPanel = PM.mk("Frame", PM.UI.Gui, {
            Name = "SettingsPanel",
            Size = UDim2.new(0, 280, 0, 320),
            Position = UDim2.new(0.5, -140, 0, 35),
            BackgroundColor3 = C.bg,
            BackgroundTransparency = 0.2,
            BorderSizePixel = 0,
            Visible = false,
            ZIndex = 100,
            ClipsDescendants = true,
        })
        PM.corner(PM.UI.SettingsPanel, 12)
        PM.stroke(PM.UI.SettingsPanel, C.border, 1, 0.4)

        PM.UI.SettingsTitle = PM.mk("TextLabel", PM.UI.SettingsPanel, {
            Size = UDim2.new(1, 0, 0, 36),
            Position = UDim2.new(0, 0, 0, 0),
            BackgroundTransparency = 1,
            Text = "Settings",
            TextColor3 = C.text,
            TextSize = 14,
            Font = Enum.Font.GothamBlack,
            TextYAlignment = Enum.TextYAlignment.Center,
            ZIndex = 101,
        })

        PM.UI.SettingsClose = PM.mk("TextButton", PM.UI.SettingsPanel, {
            Size = UDim2.new(0, 24, 0, 24),
            Position = UDim2.new(1, -30, 0, 6),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Text = "X",
            TextColor3 = C.text,
            TextSize = 11,
            Font = Enum.Font.GothamBold,
            ZIndex = 101,
        })
        PM.corner(PM.UI.SettingsClose, 6)

        PM.UI.SettingsClose.MouseEnter:Connect(function()
            PM.UI.SettingsClose.TextColor3 = Color3.fromRGB(255, 80, 80)
        end)
        PM.UI.SettingsClose.MouseLeave:Connect(function()
            PM.UI.SettingsClose.TextColor3 = C.text
        end)

        PM.UI.SettingsClose.MouseButton1Click:Connect(function()
            PM.playClickSound()
            PM.isSettingsOpen = false
            PM.closeSettingsPanel()
        end)

        PM.UI.SettingsButtonContainer = PM.mk("Frame", PM.UI.SettingsPanel, {
            Name = "ButtonContainer",
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 38),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            ZIndex = 101,
        })
        PM.corner(PM.UI.SettingsButtonContainer, 6)

        PM.mk("UIListLayout", PM.UI.SettingsButtonContainer, {
            Padding = UDim.new(0, 4),
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            VerticalAlignment = Enum.VerticalAlignment.Center,
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        local function makeTabBtn(name, text, layout, isActive)
            local btn = PM.mk("TextButton", PM.UI.SettingsButtonContainer, {
                Name = name,
                Size = UDim2.new(0.5, -6, 1, -6),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = isActive and 0.3 or 0.7,
                BorderSizePixel = 0,
                Text = text,
                TextColor3 = C.text,
                TextSize = 9,
                Font = Enum.Font.Gotham,
                AutoButtonColor = false,
                LayoutOrder = layout,
                ZIndex = 102,
            })
            PM.corner(btn, 4)

            btn.MouseEnter:Connect(function()
                if PM.activeSettingsTab ~= btn then
                    PM.tween(btn, 0.15, {BackgroundTransparency = 0.5})
                end
            end)
            btn.MouseLeave:Connect(function()
                if PM.activeSettingsTab ~= btn then
                    PM.tween(btn, 0.15, {BackgroundTransparency = 0.7})
                end
            end)

            return btn
        end

        PM.UI.SettingsTabAutoExec = makeTabBtn("AutoExecBtn", "Auto Execute", 1, true)
        PM.UI.SettingsTabSound = makeTabBtn("SoundBtn", "Sound", 2, false)
        PM.activeSettingsTab = PM.UI.SettingsTabAutoExec

        local function setActiveTab(activeBtn)
            PM.activeSettingsTab = activeBtn
            for _, btn in ipairs({PM.UI.SettingsTabAutoExec, PM.UI.SettingsTabSound}) do
                PM.tween(btn, 0.15, {BackgroundTransparency = 0.7})
            end
            PM.tween(activeBtn, 0.15, {BackgroundTransparency = 0.3})
            if PM.UI.AutoExecContent then
                PM.UI.AutoExecContent.Visible = (activeBtn == PM.UI.SettingsTabAutoExec)
            end
            if PM.UI.SoundContent then
                PM.UI.SoundContent.Visible = (activeBtn == PM.UI.SettingsTabSound)
            end
        end

        PM.UI.SettingsTabAutoExec.MouseButton1Click:Connect(function()
            PM.playClickSound()
            setActiveTab(PM.UI.SettingsTabAutoExec)
        end)
        PM.UI.SettingsTabSound.MouseButton1Click:Connect(function()
            PM.playClickSound()
            setActiveTab(PM.UI.SettingsTabSound)
        end)

        PM.UI.AutoExecContent = PM.mk("Frame", PM.UI.SettingsPanel, {
            Name = "AutoExecContent",
            Size = UDim2.new(1, 0, 0, 240),
            Position = UDim2.new(0, 0, 0, 70),
            BackgroundTransparency = 1,
            ZIndex = 101,
        })

        local function createToggleRow(parent, name, labelText, yPos, defaultState, onToggle)
            local bg = PM.mk("Frame", parent, {
                Name = name .. "Bg",
                Size = UDim2.new(1, -16, 0, 26),
                Position = UDim2.new(0, 8, 0, yPos),
                BackgroundColor3 = C.card,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                ZIndex = 102,
            })
            PM.corner(bg, 6)

            PM.mk("TextLabel", bg, {
                Size = UDim2.new(1, -56, 0, 20),
                Position = UDim2.new(0, 8, 0, 3),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 103,
            })

            local switch = PM.mk("Frame", bg, {
                Name = name .. "Switch",
                Size = UDim2.new(0, 26, 0, 13),
                Position = UDim2.new(1, -36, 0.5, 0),
                AnchorPoint = Vector2.new(0, 0.5),
                BackgroundColor3 = defaultState and Color3.fromRGB(80, 80, 80) or Color3.fromRGB(50, 50, 50),
                BorderSizePixel = 0,
                ZIndex = 103,
            })
            PM.corner(switch, 10)

            local circle = PM.mk("Frame", switch, {
                Name = name .. "Circle",
                Size = UDim2.new(0, 9, 0, 9),
                Position = defaultState and UDim2.new(1, -11, 0.5, -4) or UDim2.new(0, 2, 0.5, -4),
                BackgroundColor3 = Color3.fromRGB(235, 235, 235),
                BorderSizePixel = 0,
                ZIndex = 104,
            })
            PM.corner(circle, 10)

            local hitBtn = PM.mk("TextButton", switch, {
                Name = name .. "Hit",
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 105,
            })

            local state = defaultState
            hitBtn.MouseButton1Click:Connect(function()
                PM.playClickSound()
                state = not state
                if state then
                    PM.tween(switch, 0.2, {BackgroundColor3 = Color3.fromRGB(80, 80, 80)})
                    PM.tween(circle, 0.2, {Position = UDim2.new(1, -11, 0.5, -4)})
                else
                    PM.tween(switch, 0.2, {BackgroundColor3 = Color3.fromRGB(50, 50, 50)})
                    PM.tween(circle, 0.2, {Position = UDim2.new(0, 2, 0.5, -4)})
                end
                if onToggle then onToggle(state) end
            end)

            return bg
        end

        -- Save settings to file (settings already loaded at top of script)
        local function saveSettings()
            if not writefile then return end
            pcall(function()
                if not isfolder("prism") then
                    makefolder("prism")
                end
                local settings = {
                    autoExecutePrism = PM.autoExecutePrism,
                    autoExecuteCommands = PM.autoExecuteCommands,
                    terminalKeybind = PM.terminalKeybind,
                }
                writefile("prism/prism_settings.json", game:GetService("HttpService"):JSONEncode(settings))
            end)
        end
        
        -- Initialize with loaded or default values (loaded at top of script)
        local autoExecPrismDefault = PM.autoExecutePrism or false
        local autoExecCommandsDefault = PM.autoExecuteCommands ~= false
        PM.terminalKeybind = PM.terminalKeybind or "F6"
        
        PM.autoExecutePrism = autoExecPrismDefault
        PM.autoExecuteCommands = autoExecCommandsDefault

        -- Setup teleport check for auto execute prism (matching Infinite Yield pattern)
        pcall(function()
            local TeleportCheck = false
            local queueteleport = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or (krnl and krnl.queue_on_teleport) or (is_sirius and is_sirius.queue_on_teleport)
            
            if queueteleport and Players.LocalPlayer then
                Players.LocalPlayer.OnTeleport:Connect(function(State)
                    if PM.autoExecutePrism and (not TeleportCheck) and queueteleport then
                        TeleportCheck = true
                        pcall(function()
                            queueteleport([[loadstring(game:HttpGet("https://prismscript.vercel.app/Prism.lua"))()]])
                        end)
                    end
                end)
            end
        end)

        createToggleRow(PM.UI.AutoExecContent, "AutoExecPrism", "Auto execute prism", 0, autoExecPrismDefault, function(state)
            PM.autoExecutePrism = state
            saveSettings()
        end)

        createToggleRow(PM.UI.AutoExecContent, "AutoExecuteCommands", "Auto execute commands", 28, autoExecCommandsDefault, function(state)
            PM.autoExecuteCommands = state
            saveSettings()
        end)

        PM.UI.AutoExecSearch = PM.mk("TextBox", PM.UI.AutoExecContent, {
            Name = "AutoExecSearch",
            Size = UDim2.new(1, -16, 0, 28),
            Position = UDim2.new(0, 8, 0, 56),
            BackgroundColor3 = C.card,
            BackgroundTransparency = 0.5,
            BorderSizePixel = 0,
            Text = "",
            PlaceholderText = "Search commands...",
            PlaceholderColor3 = C.textDim,
            TextColor3 = C.text,
            TextSize = 12,
            Font = Enum.Font.Gotham,
            ClearTextOnFocus = true,
            ZIndex = 102,
        })
        PM.corner(PM.UI.AutoExecSearch, 6)

        PM.UI.AutoExecScroll = PM.mk("ScrollingFrame", PM.UI.AutoExecContent, {
            Name = "AutoExecScroll",
            Size = UDim2.new(1, -10, 1, -88),
            Position = UDim2.new(0, 9, 0, 88),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 0),
            ZIndex = 102,
        })

        PM.UI.AutoExecList = PM.mk("UIListLayout", PM.UI.AutoExecScroll, {
            Padding = UDim.new(0, 2),
            SortOrder = Enum.SortOrder.LayoutOrder,
        })

        PM.UI.AutoExecList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            PM.UI.AutoExecScroll.CanvasSize = UDim2.new(0, 0, 0, PM.UI.AutoExecList.AbsoluteContentSize.Y)
        end)

        -- ========== SOUND CONTENT ==========
        PM.UI.SoundContent = PM.mk("Frame", PM.UI.SettingsPanel, {
            Name = "SoundContent",
            Size = UDim2.new(1, 0, 0, 240),
            Position = UDim2.new(0, 0, 0, 70),
            BackgroundTransparency = 1,
            Visible = false,
            ZIndex = 101,
        })

        PM.UI.SoundScroll = PM.mk("ScrollingFrame", PM.UI.SoundContent, {
            Name = "SoundScroll",
            Size = UDim2.new(1, -10, 1, 0),
            Position = UDim2.new(0, 9, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            ScrollBarThickness = 3,
            ScrollBarImageColor3 = C.border,
            CanvasSize = UDim2.new(0, 0, 0, 266),
            ZIndex = 102,
        })

        local function makeSectionLabel(parent, text, yPos)
            PM.mk("TextLabel", parent, {
                Size = UDim2.new(1, -16, 0, 14),
                Position = UDim2.new(0, 8, 0, yPos),
                BackgroundTransparency = 1,
                Text = text,
                TextColor3 = C.textDim,
                TextSize = 9,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 103,
            })
        end

        local function makeSliderRow(parent, name, labelText, yPos, defaultValue, onChange)
            local bg = PM.mk("Frame", parent, {
                Name = name .. "Bg",
                Size = UDim2.new(1, -16, 0, 38),
                Position = UDim2.new(0, 8, 0, yPos),
                BackgroundColor3 = C.card,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                ZIndex = 103,
            })
            PM.corner(bg, 6)

            PM.mk("TextLabel", bg, {
                Size = UDim2.new(1, -80, 0, 16),
                Position = UDim2.new(0, 8, 0, 4),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 104,
            })

            local valueLabel = PM.mk("TextLabel", bg, {
                Name = "ValueLabel",
                Size = UDim2.new(0, 40, 0, 16),
                Position = UDim2.new(1, -48, 0, 4),
                BackgroundTransparency = 1,
                Text = string.format("%.2f", defaultValue),
                TextColor3 = C.textDim,
                TextSize = 9,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 104,
            })

            local track = PM.mk("TextButton", bg, {
                Name = name .. "Track",
                Size = UDim2.new(1, -20, 0, 4),
                Position = UDim2.new(0, 10, 0, 26),
                BackgroundColor3 = Color3.fromRGB(30, 30, 38),
                BorderSizePixel = 0,
                Text = "",
                AutoButtonColor = false,
                ZIndex = 104,
            })
            PM.corner(track, 4)

            local fill = PM.mk("Frame", track, {
                Name = name .. "Fill",
                Size = UDim2.new(defaultValue, 0, 1, 0),
                BackgroundColor3 = C.text,
                BorderSizePixel = 0,
                ZIndex = 105,
            })
            PM.corner(fill, 4)

            local knob = PM.mk("Frame", track, {
                Name = name .. "Knob",
                Size = UDim2.new(0, 10, 0, 10),
                Position = UDim2.new(defaultValue, -5, 0.5, -5),
                BackgroundColor3 = C.text,
                BorderSizePixel = 0,
                ZIndex = 106,
            })
            PM.corner(knob, 6)

            local currentValue = defaultValue
            local isDragging = false

            local function updateSlider(input)
                local sliderWidth = track.AbsoluteSize.X
                local relativeX = math.clamp(input.Position.X - track.AbsolutePosition.X, 0, sliderWidth)
                local newValue = relativeX / sliderWidth
                currentValue = newValue
                fill.Size = UDim2.new(newValue, 0, 1, 0)
                knob.Position = UDim2.new(newValue, -5, 0.5, -5)
                valueLabel.Text = string.format("%.2f", newValue)
                if onChange then onChange(newValue) end
            end

            knob.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    isDragging = true
                end
            end)

            track.MouseButton1Down:Connect(function(input)
                isDragging = true
                updateSlider(input)
            end)

            game:GetService("UserInputService").InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 and isDragging then
                    isDragging = false
                end
            end)

            game:GetService("UserInputService").InputChanged:Connect(function(input)
                if isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    updateSlider(input)
                end
            end)

            return bg
        end

        local function makeSoundIDRow(parent, name, labelText, yPos, defaultID, onChange)
            local bg = PM.mk("Frame", parent, {
                Name = name .. "Bg",
                Size = UDim2.new(1, -16, 0, 48),
                Position = UDim2.new(0, 8, 0, yPos),
                BackgroundColor3 = C.card,
                BackgroundTransparency = 0.5,
                BorderSizePixel = 0,
                ZIndex = 103,
            })
            PM.corner(bg, 6)

            PM.mk("TextLabel", bg, {
                Size = UDim2.new(1, -16, 0, 16),
                Position = UDim2.new(0, 8, 0, 4),
                BackgroundTransparency = 1,
                Text = labelText,
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 104,
            })

            local box = PM.mk("TextBox", bg, {
                Size = UDim2.new(1, -20, 0, 20),
                Position = UDim2.new(0, 10, 0, 22),
                BackgroundColor3 = C.bg,
                BackgroundTransparency = 0.3,
                BorderSizePixel = 0,
                ClearTextOnFocus = false,
                PlaceholderText = "Sound Asset ID...",
                PlaceholderColor3 = C.textDim,
                Text = defaultID,
                TextColor3 = C.text,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                ZIndex = 104,
            })
            PM.corner(box, 3)

            box.FocusLost:Connect(function()
                if box.Text ~= "" and onChange then
                    onChange(box.Text)
                end
            end)

            return bg
        end

        -- CLICK SOUND section
        makeSectionLabel(PM.UI.SoundScroll, "CLICK SOUND", 0)
        createToggleRow(PM.UI.SoundScroll, "ClickSoundToggle", "Enable Click Sound", 16, PM.clickSoundEnabled, function(state)
            PM.clickSoundEnabled = state
        end)
        makeSliderRow(PM.UI.SoundScroll, "ClickVolume", "Click Volume", 44, PM.clickVolume, function(val)
            PM.clickVolume = val
            if PM.UI.ClickSound then PM.UI.ClickSound.Volume = val end
        end)
        makeSoundIDRow(PM.UI.SoundScroll, "ClickSoundID", "Click Sound ID", 84, PM.clickSoundID, function(id)
            PM.clickSoundID = id
            if PM.UI.ClickSound then PM.UI.ClickSound.SoundId = "rbxassetid://" .. id end
        end)

        -- HOVER SOUND section
        makeSectionLabel(PM.UI.SoundScroll, "HOVER SOUND", 134)
        createToggleRow(PM.UI.SoundScroll, "HoverSoundToggle", "Enable Hover Sound", 150, PM.hoverSoundEnabled, function(state)
            PM.hoverSoundEnabled = state
        end)
        makeSliderRow(PM.UI.SoundScroll, "HoverVolume", "Hover Volume", 178, PM.hoverVolume, function(val)
            PM.hoverVolume = val
            if PM.UI.HoverSound then PM.UI.HoverSound.Volume = val end
        end)
        makeSoundIDRow(PM.UI.SoundScroll, "HoverSoundID", "Hover Sound ID", 218, PM.hoverSoundID, function(id)
            PM.hoverSoundID = id
            if PM.UI.HoverSound then PM.UI.HoverSound.SoundId = "rbxassetid://" .. id end
        end)

        setActiveTab(PM.UI.SettingsTabAutoExec)
    end

    PM.openSettingsPanel = function()
        if not PM.UI.SettingsPanel then
            PM.createSettingsPanel()
        end
        PM.isSettingsOpen = true
        PM.UI.SettingsPanel.Visible = true
        PM.UI.SettingsPanel.Size = UDim2.new(0, 280, 0, 0)
        PM.tween(PM.UI.SettingsPanel, 0.3, {Size = UDim2.new(0, 280, 0, 320)})
    end

    PM.closeSettingsPanel = function()
        if not PM.UI.SettingsPanel or not PM.UI.SettingsPanel.Visible then return end
        PM.isSettingsOpen = false
        PM.tween(PM.UI.SettingsPanel, 0.3, {Size = UDim2.new(0, 280, 0, 0)})
        task.delay(0.3, function()
            PM.UI.SettingsPanel.Visible = false
            PM.UI.SettingsPanel.Size = UDim2.new(0, 280, 0, 320)
        end)
    end

    PM.hideSettingsPanel = function()
        if not PM.UI.SettingsPanel then return end
        PM.isSettingsOpen = false
        PM.UI.SettingsPanel.Visible = false
        PM.UI.SettingsPanel.Size = UDim2.new(0, 280, 0, 320)
    end

    PM.UI.LeftDivider = PM.mk("Frame", PM.UI.Main, {
        Name = "LeftDivider",
        Size = UDim2.new(0, 1, 0, 44),
        Position = UDim2.new(0, 70, 0.5, -22),
        BackgroundColor3 = C.border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 10,
    })

    PM.UI.RightDivider = PM.mk("Frame", PM.UI.Main, {
        Name = "RightDivider",
        Size = UDim2.new(0, 1, 0, 44),
        Position = UDim2.new(1, -70, 0.5, -22),
        BackgroundColor3 = C.border,
        BackgroundTransparency = 0.5,
        BorderSizePixel = 0,
        ZIndex = 10,
    })
    
    PM.UI.RightFrame = PM.mk("Frame", PM.UI.Main, {
        Name = "RightFrame",
        Size = UDim2.new(0, 130, 0, 44),
        Position = UDim2.new(1, -136, 0.5, -22),
        BackgroundTransparency = 1,
        ZIndex = 10,
    })
    
    PM.UI.PrismLabel = PM.mk("TextLabel", PM.UI.RightFrame, {
        Name = "PrismLabel",
        Size = UDim2.new(1, -32, 0, 14),
        Position = UDim2.new(0, 25, 0, 2),
        BackgroundTransparency = 1,
        Text = "PRISM",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.GothamBlack,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    PM.UI.PlayerCountLabel = PM.mk("TextLabel", PM.UI.RightFrame, {
        Name = "PlayerCountLabel",
        Size = UDim2.new(1, -32, 0, 14),
        Position = UDim2.new(0, 25, 0, 23),
        BackgroundTransparency = 1,
        Text = "0/0",
        TextColor3 = C.text,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Right,
    })
    
    PM.UI.LogoFrame = PM.mk("Frame", PM.UI.RightFrame, {
        Name = "LogoFrame",
        Size = UDim2.new(0, 26, 0, 26),
        Position = UDim2.new(1, -26, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Rotation = 315,
    })
    
    PM.UI.LogoBg = PM.mk("ImageLabel", PM.UI.LogoFrame, {
        Name = "LogoBg",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Image = "rbxassetid://6734565426",
        ImageColor3 = C.accent,
    })
    
    local currentRotation = 315
    PM.Svc.RunService.Heartbeat:Connect(function(deltaTime)
        if PM.UI.Gui and PM.UI.Gui.Parent and PM.UI.LogoFrame then
            currentRotation = currentRotation + (120 * deltaTime)
            PM.UI.LogoFrame.Rotation = currentRotation
        end
    end)
    
    task.spawn(function()
        PM.UI.Main.Position = UDim2.new(0.5, -230, 0, -120)
        task.wait(0.2)
        PM.tween(PM.UI.Main, 0.6, {Position = UDim2.new(0.5, -230, 0, -30)})
    end)
    
    local frames = 0
    local lastT = tick()
    PM.Svc.RunService.RenderStepped:Connect(function()
        frames = frames + 1
        local now = tick()
        if now - lastT >= 1 then
            local fps = frames
            frames = 0
            lastT = now
            if PM.UI.FPSLabel then
                PM.UI.FPSLabel.Text = fps
                if fps < 30 then
                    PM.UI.FPSLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                elseif fps < 60 then
                    PM.UI.FPSLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
                else
                    PM.UI.FPSLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
                end
            end
        end
    end)
    
    task.spawn(function()
        while PM.UI.Gui and PM.UI.Gui.Parent do
            local ping = math.round(LP:GetNetworkPing() * 1000)
            if PM.UI.PingLabel then
                PM.UI.PingLabel.Text = ping
                if ping < 50 then
                    PM.UI.PingLabel.TextColor3 = Color3.fromRGB(80, 220, 120)
                elseif ping < 150 then
                    PM.UI.PingLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
                else
                    PM.UI.PingLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
                end
            end
            task.wait(2)
        end
    end)
    
    local function updatePlayerCount()
        local currentPlayers = #PM.Svc.Players:GetPlayers()
        local maxPlayers = PM.Svc.Players.MaxPlayers
        if PM.UI.PlayerCountLabel then
            PM.UI.PlayerCountLabel.Text = currentPlayers .. "/" .. maxPlayers
        end
    end
    
    PM.Svc.Players.PlayerAdded:Connect(updatePlayerCount)
    PM.Svc.Players.PlayerRemoving:Connect(updatePlayerCount)
    updatePlayerCount()
    
    -- Fetch servers on execute and auto-refresh every 5 minutes
    task.spawn(function()
        PM.fetchServers()
        while true do
            task.wait(300) -- 5 minutes
            PM.fetchServers()
        end
    end)
end

repeat task.wait() until LP

pcall(PM.createMainGUI)

-- Initialize nametag system
clearAllNametags()
local player = PM.Svc.Players.LocalPlayer
if player.Character then
    createNametag()
end

player.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    if nametagEnabled then
        createNametag()
    end
    -- Recreate other players' nametags since PlayerGui was reset
    updateOtherNametags()
end)

-- Remove nametag when player leaves
PM.Svc.Players.PlayerRemoving:Connect(function(leavingPlayer)
    removeOtherNametag(leavingPlayer.UserId)
    -- Also remove from API instantly
    task.spawn(function()
        deleteFromAPI(leavingPlayer.UserId)
    end)
end)

-- Check for other Prism users on load
task.wait(1)
updateOtherNametags()

-- Poll loop failsafe: remove nametags for players no longer in server
task.spawn(function()
    while autoSyncEnabled do
        task.wait(2) -- Check every 2 seconds (like env.lua)
        pcall(function()
            local currentPlayers = {}
            for _, plrObj in ipairs(PM.Svc.Players:GetPlayers()) do
                currentPlayers[plrObj.UserId] = true
            end
            
            for userId, tagData in pairs(otherNametags) do
                if not currentPlayers[userId] then
                    removeOtherNametag(userId)
                end
            end
        end)
    end
end)

-- Send initial data IMMEDIATELY on execute
sendNametagData()

-- Start auto-sync in background
task.spawn(startAutoSync)

-- Panel population is handled by Prism Commands.lua after it loads

-- Global terminal keybind handler (only opens, never closes like Mono's bar)
game:GetService("UserInputService").InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    local keybind = PM.terminalKeybind or "F6"
    if input.KeyCode.Name == keybind then
        -- Skip if panel just opened (prevents immediate close after opening)
        if PM.panelJustOpened then return end
        -- Create panel if it doesn't exist
        if not PM.UI.TerminalPanel and PM.createTerminalPanel then
            PM.createTerminalPanel()
        end
        -- Only open if not already visible (never close with keybind)
        if PM.UI.TerminalPanel and not PM.UI.TerminalPanel.Visible and PM.openTerminalPanel then
            -- Hide other panels before opening terminal (like button click does)
            if PM.isCommandsOpen then
                PM.isCommandsOpen = false
                PM.hideCommandsPanel()
            end
            if PM.isServersOpen then
                PM.isServersOpen = false
                PM.hideServersPanel()
            end
            if PM.UI.NameTagsPanel and PM.UI.NameTagsPanel.Visible then
                PM.UI.NameTagsPanel.Visible = false
            end
            if PM.isJoinOpen then
                PM.isJoinOpen = false
                PM.hideJoinPanel()
            end
            if PM.isSettingsOpen then
                PM.isSettingsOpen = false
                PM.hideSettingsPanel()
            end
            PM.openTerminalPanel()
        end
    end
end)

-- Auto execute prism on teleport (like Mono's auto load)
local queueTeleport = queue_on_teleport or queueonteleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport) or (krnl and krnl.queue_on_teleport) or (is_sirius and is_sirius.queue_on_teleport)

if queueTeleport and PM.autoExecutePrism then
    pcall(function()
        queueTeleport([[loadstring(game:HttpGet("https://prismscript.vercel.app/Prism.lua"))()]])
    end)
end

return PM
