#pragma once

#include <DirectXMath.h>

struct Vertex
{
	DirectX::XMFLOAT3	pos;
	DirectX::XMFLOAT3	normal;
};

// Box
void GetBoxVertexAndIndexCount(int& vcount, int& icount);
void CreateBoxVertexAndIndex(Vertex* pVertex, unsigned short* pIndex);

// Sphere
void GetShpereVertexAndIndexCount(int longCount, int latiCount, int& vcount, int& icount);
void CreateSphereVertexAndIndex(int longCount, int latiCount, Vertex* pVertex, unsigned short* pIndex);

//	EOF
