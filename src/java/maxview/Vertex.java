/**
  This file is part of a 3D engine,
  copyright Arne Vansteenkiste 2006-2010.
  Use of this source code is governed by the GNU General Public License version 3,
  as published by the Free Software Foundation.
*/
package maxview;
import java.io.Serializable;

/*  
BarneX 3D Engine.  Copyright Arne Vansteenkiste 2006.
*/
public final class Vertex implements Serializable{
	
    //Coordinaten in het universum.
    public double x, y, z;
    
    //Getransformeerde Coordinaten.
    public double tx, ty, tz;
    

    public Vertex(double x, double y, double z){
        this.x = x;
        this.y = y; 
        this.z = z;
    }
    
    
    public void translate(double dx, double dy, double dz){
        x += dx;
        y += dy;
        z += dz;
    }
    
    
    public Vertex copy(){
        return new Vertex(x, y, z);
    }
}
