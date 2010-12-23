/**
  This file is part of a 3D engine,
  copyright Arne Vansteenkiste 2006-2010.
  Use of this source code is governed by the GNU General Public License version 3,
  as published by the Free Software Foundation.
*/
import javax.swing.*;
import java.awt.*;
import java.io.*;
import java.lang.Math.*;

public class Maxview {

    public static void main (String args[]) throws IOException{

      

     Group root = new Group();
     readFile(args[0], root);


    Universe universe = new Universe(Color.WHITE, new Vertex(2, 5, 0), 1);
    View view = new View(universe);
    view.setBord(10, 0, 0.3);
    universe.setRoot(root);

    JFrame frame = new JFrame("3D Engine");
    frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
    frame.setContentPane(view);
    frame.setSize(400, 300);
    frame.show();
	}

  private static void readFile(String file, Group root) throws IOException{
    StreamTokenizer in = new StreamTokenizer(new InputStreamReader(new FileInputStream(new File(file))));

    int tok = in.nextToken();
    while(tok != StreamTokenizer.TT_EOF){
      double x = in.nval; tok = in.nextToken();
      double y = in.nval; tok = in.nextToken();
      double z = in.nval; tok = in.nextToken();
      double mx = in.nval; tok = in.nextToken();
      double my = in.nval; tok = in.nextToken();
      double mz = in.nval; tok = in.nextToken();


      Brush cone = Factory.cone(0.4, 32, 1);
      cone.rotate(0, -Math.PI/2);
      cone.setFillColor(Color.RED);
      cone.translate(x, y, z);
      root.add(cone);

      
    }
  }
}
