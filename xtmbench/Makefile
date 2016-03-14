CXX=g++
CXXFLAGS=-g -Wall -O2 -pthread

all: xtmbench

xtmbench: xtmbench.cpp
	$(CXX) $(CXXFLAGS) -o xtmbench xtmbench.cpp -lpqxx

clean:
	rm -f xtmbench
