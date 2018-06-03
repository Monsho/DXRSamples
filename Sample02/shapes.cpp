#include "stdafx.h"

#include "shapes.h"

#include <stdio.h>
#include <algorithm>

namespace
{
	static const Vertex kBoxVertices[] = {
		{ { -1.0f,  1.0f, -1.0f },{ 0.0f, 1.0f, 0.0f } },
		{ {  1.0f,  1.0f, -1.0f },{ 0.0f, 1.0f, 0.0f } },
		{ { -1.0f,  1.0f,  1.0f },{ 0.0f, 1.0f, 0.0f } },
		{ {  1.0f,  1.0f,  1.0f },{ 0.0f, 1.0f, 0.0f } },

		{ {  1.0f, -1.0f, -1.0f },{ 0.0f,-1.0f, 0.0f } },
		{ { -1.0f, -1.0f, -1.0f },{ 0.0f,-1.0f, 0.0f } },
		{ {  1.0f, -1.0f,  1.0f },{ 0.0f,-1.0f, 0.0f } },
		{ { -1.0f, -1.0f,  1.0f },{ 0.0f,-1.0f, 0.0f } },

		{ {  1.0f,  1.0f, -1.0f },{ 1.0f, 0.0f, 0.0f } },
		{ {  1.0f,  1.0f,  1.0f },{ 1.0f, 0.0f, 0.0f } },
		{ {  1.0f, -1.0f, -1.0f },{ 1.0f, 0.0f, 0.0f } },
		{ {  1.0f, -1.0f,  1.0f },{ 1.0f, 0.0f, 0.0f } },

		{ { -1.0f,  1.0f, -1.0f },{ -1.0f, 0.0f, 0.0f } },
		{ { -1.0f,  1.0f,  1.0f },{ -1.0f, 0.0f, 0.0f } },
		{ { -1.0f, -1.0f, -1.0f },{ -1.0f, 0.0f, 0.0f } },
		{ { -1.0f, -1.0f,  1.0f },{ -1.0f, 0.0f, 0.0f } },

		{ { -1.0f,  1.0f, -1.0f },{ 0.0f, 0.0f,-1.0f } },
		{ {  1.0f,  1.0f, -1.0f },{ 0.0f, 0.0f,-1.0f } },
		{ { -1.0f, -1.0f, -1.0f },{ 0.0f, 0.0f,-1.0f } },
		{ {  1.0f, -1.0f, -1.0f },{ 0.0f, 0.0f,-1.0f } },

		{ { -1.0f,  1.0f,  1.0f },{ 0.0f, 0.0f, 1.0f } },
		{ {  1.0f,  1.0f,  1.0f },{ 0.0f, 0.0f, 1.0f } },
		{ { -1.0f, -1.0f,  1.0f },{ 0.0f, 0.0f, 1.0f } },
		{ {  1.0f, -1.0f,  1.0f },{ 0.0f, 0.0f, 1.0f } },
	};
	static const unsigned short kBoxIndices[] =
	{
		0, 2, 1, 1, 2, 3,
		4, 6, 5, 5, 6, 7,
		8, 9, 10, 9, 11, 10,
		12, 14, 13, 13, 14, 15,
		16, 17, 18, 17, 19, 18,
		20, 22, 21, 21, 22, 23,
	};
}

// Box
void GetBoxVertexAndIndexCount(int& vcount, int& icount)
{
	vcount = sizeof(kBoxVertices) / sizeof(kBoxVertices[0]);
	icount = sizeof(kBoxIndices) / sizeof(kBoxIndices[0]);
}
void CreateBoxVertexAndIndex(Vertex* pVertex, unsigned short* pIndex)
{
	memcpy(pVertex, kBoxVertices, sizeof(kBoxVertices));
	memcpy(pIndex, kBoxIndices, sizeof(kBoxIndices));
}

// Sphere
void GetShpereVertexAndIndexCount(int longCount, int latiCount, int& vcount, int& icount)
{
	longCount = std::max<int>(longCount, 4);
	latiCount = std::max<int>(latiCount, 2);

	vcount = longCount * (latiCount - 1) + 2;
	icount = longCount * 3 * 2 + longCount * 6 * (latiCount - 2);
}
void CreateSphereVertexAndIndex(int longCount, int latiCount, Vertex* pVertex, unsigned short* pIndex)
{
	// vertex
	pVertex->pos = pVertex->normal = DirectX::XMFLOAT3(0.0f, 1.0f, 0.0f);
	pVertex++;

	for (int y = 0; y < latiCount - 1; y++)
	{
		float h = 2.0f * (float)(latiCount - 1 - y) / (float)latiCount - 1.0f;
		float xzLen = sqrtf(1.0f - h * h);

		for (int x = 0; x < longCount; x++)
		{
			float angle = DirectX::XM_2PI * (float)x / (float)longCount;

			pVertex->pos = pVertex->normal = DirectX::XMFLOAT3(cosf(angle) * xzLen, h, sinf(angle) * xzLen);
			pVertex++;
		}
	}

	pVertex->pos = pVertex->normal = DirectX::XMFLOAT3(0.0f, -1.0f, 0.0f);
	pVertex++;

	// index
	unsigned short baseCount = 1;
	for (int x = 0; x < longCount; x++)
	{
		pIndex[0] = 0;
		pIndex[1] = (x + 1) % longCount + baseCount;
		pIndex[2] = (x + 0) % longCount + baseCount;
		pIndex += 3;
	}

	for (int y = 0; y < latiCount - 2; y++)
	{
		unsigned short nextCount = baseCount + longCount;
		for (int x = 0; x < longCount; x++)
		{
			pIndex[0] = (x + 0) % longCount + baseCount;
			pIndex[1] = (x + 1) % longCount + baseCount;
			pIndex[2] = (x + 0) % longCount + nextCount;
			pIndex += 3;

			pIndex[0] = (x + 1) % longCount + baseCount;
			pIndex[1] = (x + 1) % longCount + nextCount;
			pIndex[2] = (x + 0) % longCount + nextCount;
			pIndex += 3;
		}
		baseCount = nextCount;
	}

	unsigned short lastCount = baseCount + longCount;
	for (int x = 0; x < longCount; x++)
	{
		pIndex[0] = lastCount;
		pIndex[1] = (x + 0) % longCount + baseCount;
		pIndex[2] = (x + 1) % longCount + baseCount;
		pIndex += 3;
	}
}

//	EOF
