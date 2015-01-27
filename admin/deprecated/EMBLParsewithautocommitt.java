import java.io.*;
import java.util.StringTokenizer; 
import java.math.*;
import java.io.File;
import java.io.FileNotFoundException;
import java.util.Scanner;
import java.io.BufferedWriter;
import java.io.FileNotFoundException;
import java.io.FileWriter;
import java.io.IOException;
import java.sql.*;

class EMBLParsewithautocommitt
{
    public static void main(String args[])
    {
        try{
            File file = new File(args[0]);
            Scanner scanner = new Scanner(file);
            String strLine;
            String strLine2;
            int ArrayInitialize= 0;
            int RefSeqCounter = 0;
            String TokenCheck = "";
			int SentFLAG = 0;
            int PostArrayCounter = 0;
            String ProtNameTempHolder = "";
            String UniprotRemoveElementsHolder = "";
            String GeneNameTempHolder = "";
            String DETokenHolder= "";
            String RefSeqTempHolder = "";
            String EMBLSeqTempHolder = "";
            String GeneIdTempHolder = "";
            String GeneNameTokenHolder="";
            String TaxonomyTempHolder="";
            String TaxTempTokenHolder="";
			String TempSequneceHodler = "";
			String SeqForBuild ="";
			String SeqeunceValueForPrint = "";
            String GOTempTokenHolder = "";
            String eggNOGTempTokenHolder = "";
            String NCBITaxNumericalValueClipped = "";
            String KEGGTempTokenHolder= "";
            String GOvalueTempTokenHolder = "";
            String KeyWorkTempTokenHolder = "";
            String UniprotDbaseTokenHolder;
            String DETokenCheck = "DE";
            String[] NCBITaxSplit;
            String GNTokenCheck = "GN";
            String OCTokenCheck = "OC";
            String OXTokenCheck = "OX";
            String DRtokencheck = "DR";
            String IDtokencheck = "AC";
			String SeqTokenCheck = "SQ";
            String DBTokenHolder = "";
            String REFSeqtokencheck = "RefSeq;";
            String GeneIDtokencheck = "GeneID;";
            String KEGGTokenCheck = "KEGG;";
            String EMBLTokenCheck = "EMBL;";
            String eggNOGTokenCheck = "eggNOG;";
            String NCBITaxNumericalValue = "";
            String KWTokenCheck = "KW";
            String GOtokencheck = "GO;";
            String NCBItaxDelimit = "=";
            String OxForSplit = "";
            String FuncaitonalDataHeap= "";
            String SubString = "";
            String IdHeap ="";
            String CloseTokenHolder = "//";
            String RefSeqValue = "";
            String GoTokenValue = "";
            String EggNogValue = "";
			String TaxonomyHolderforDB ="";
            String goTermHolderforDB ="";
            String keggTermHolderforDB ="";
            String eggNOGHolderforDB ="";
            String EMBLValue = "";
            String KeggValue = "";
            String CombinedTemp = "";
            String IDValue = "";
            String GOValue = "";
			String DeffinitionAttributeFlag = "D";
            String TaxonomyAttributeFlag = "T";
            String KEGGAttributeFlag = "K";
            String goAttributeFlag = "G";
            String eggNOGAttributeFLAG = "E";
			String AccessionToCommit = "";
            String DeffinitionToCommit = "";
            String TaxonomyToCommit = "";
            String goTermToCommit = "";
            String keggToCommit = "";
            String eggNOGToCommit = "";
            String goTermForSplit = "";
			int ScanCounter = 0;
			String BarDelimit = ":";
            String[] SplitArray1;
			Class.forName("org.sqlite.JDBC");
            Connection conn = DriverManager.getConnection("jdbc:sqlite:Trinotate.sqlite");
            Statement stat = conn.createStatement();
            
            // clean it out if doing a re-run
            stat.executeUpdate("delete from UniprotIndex");

            
            PreparedStatement prep = conn.prepareStatement("insert into UniprotIndex values (?, ?, ?);");
            conn.setAutoCommit(false);
            
            
            File uniprot_parsed_data_outfile = new File("uniprot_parsed_data.dat");
            Writer uniprot_parsed_writer = new BufferedWriter(new FileWriter(uniprot_parsed_data_outfile));
            
            File taxonomy_data_file = new File("Taxonomyvalue.pre");
            Writer taxonomy_data_file_writer = new BufferedWriter(new FileWriter(taxonomy_data_file));
            

            // parsing EMBL file
            while (scanner.hasNextLine()) {
                
                ScanCounter++;
                
                if (ScanCounter % 1000 == 0) {
                    System.err.print("\r[" + ScanCounter + "]   ");
                }
                
                UniprotDbaseTokenHolder=scanner.nextLine();
                StringTokenizer st2 = new StringTokenizer(UniprotDbaseTokenHolder);
                TokenCheck=st2.nextToken();
                
                


                if(TokenCheck.equals(IDtokencheck)) {
                    if(st2.hasMoreTokens()) {
                        while (st2.hasMoreTokens()) {
                            String IdTempHolder=st2.nextToken();
                            SubString= IdTempHolder.substring(0, IdTempHolder.length()-1);
                            IdHeap = IdHeap + "   " + SubString;	  
                        }
                        IDValue =IDValue +"  "+IdHeap;
                        IdHeap="";
                    } 
                }
                else if (TokenCheck.equals(DETokenCheck)) {
                    if(st2.hasMoreTokens()) {
                        while (st2.hasMoreTokens()) {
                            String TempTokenHolder=st2.nextToken();
                            DETokenHolder=DETokenHolder +" "+TempTokenHolder;
                        }
                        ProtNameTempHolder = ProtNameTempHolder + " " + DETokenHolder ;
                        DETokenHolder="";
                    }
                }
                else if (OXTokenCheck.equals(TokenCheck))  {
                    if(st2.hasMoreTokens()) {
                        OxForSplit=st2.nextToken(); 
                        NCBITaxSplit= OxForSplit.split(NCBItaxDelimit);
                        NCBITaxNumericalValue=NCBITaxSplit[1];	
                        NCBITaxNumericalValueClipped=NCBITaxNumericalValue.substring(0, NCBITaxNumericalValue.length()-1);
                        
                    }
                } 
                else if (TokenCheck.equals(OCTokenCheck)) {
                    if(st2.hasMoreTokens()) {
                        while (st2.hasMoreTokens()) {
                            String TempTokenHolder3=st2.nextToken();
                            TaxTempTokenHolder= TaxTempTokenHolder +" "+TempTokenHolder3;
                        } 
                        TaxonomyTempHolder= TaxonomyTempHolder + " " + TaxTempTokenHolder;
                        TaxTempTokenHolder="";
                    }
                }
                else if (TokenCheck.equals(DRtokencheck)) {
                    if(st2.hasMoreTokens())  {
                        TokenCheck=st2.nextToken();
                    }
                    
                    if(st2.hasMoreTokens()) {	  
                        if (REFSeqtokencheck.equals(TokenCheck)) {
                            if(st2.hasMoreTokens()) {
                                while (st2.hasMoreTokens()) {
                                    String TempTokenHolder4=st2.nextToken();
                                    SubString= TempTokenHolder4.substring(0, TempTokenHolder4.length()-1);
                                    RefSeqTempHolder = RefSeqTempHolder + "   " + SubString;	  
                                }
                                RefSeqValue =RefSeqValue +"  "+RefSeqTempHolder;
                                RefSeqTempHolder="";
                            }
                        }
                        else if (KEGGTokenCheck.equals(TokenCheck)) {
                            
                            if(st2.hasMoreTokens()) {
                                while (st2.hasMoreTokens()) {
                                    String TempTokenHolder5=st2.nextToken();
                                    SubString= TempTokenHolder5.substring(0, TempTokenHolder5.length()-1);
                                    
                                    KEGGTempTokenHolder = KEGGTempTokenHolder + SubString;	  
                                }
                                KeggValue =KeggValue +"  "+KEGGTempTokenHolder;
                                KEGGTempTokenHolder ="";
                            }
                        }
                        
                        else if (EMBLTokenCheck.equals(TokenCheck)) {
                            if(st2.hasMoreTokens()) {
                                while (st2.hasMoreTokens()) {
                                    String TempTokenHolder8=st2.nextToken();
                                    SubString= TempTokenHolder8.substring(0, TempTokenHolder8.length()-1);
                                    EMBLSeqTempHolder = EMBLSeqTempHolder + "   " + SubString;	  
                                }
                                EMBLValue =EMBLValue +"  "+EMBLSeqTempHolder;
                                EMBLSeqTempHolder="";
                            }
                        }
                                    
                        else if (eggNOGTokenCheck.equals(TokenCheck)) {
                            
                            if(st2.hasMoreTokens()) {
                                while (st2.hasMoreTokens()) {
                                    String TempTokenHolder6=st2.nextToken();
                                    SubString= TempTokenHolder6.substring(0, TempTokenHolder6.length()-1);
                                    
                                    eggNOGTempTokenHolder = eggNOGTempTokenHolder + SubString;	  
                                }
                                EggNogValue =EggNogValue +"  "+eggNOGTempTokenHolder;
                                eggNOGTempTokenHolder="";
                                
                            }
                        }
                        else if (GOtokencheck.equals(TokenCheck)) {
                            if(st2.hasMoreTokens()) {
                                while (st2.hasMoreTokens()) {
                                    String TempTokenHolder7=st2.nextToken();
                                    SubString= TempTokenHolder7.substring(0, TempTokenHolder7.length()-1);
                                    
                                    GOvalueTempTokenHolder = GOvalueTempTokenHolder + SubString;	  
                                }
                                GOValue =GOValue +"  "+GOvalueTempTokenHolder;
                                GOvalueTempTokenHolder="";
                            }
                        }
                    }
                    
                            
                    else {
                        // noop?
                            
                    }		   
                }
                else if (TokenCheck.equals(SeqTokenCheck)) {
                    SentFLAG=1;
                }
                
                else if (CloseTokenHolder.equals(TokenCheck)) { 
                    // end of EMBL record. Load it.

                    // populating database with record
                    
                    IDValue = IDValue.trim();
                    String[] ids = IDValue.split(" ");
                    IDValue = ids[0];
                    
                    
                    AccessionToCommit =IDValue; //IndexArrayOfUniprot[n]; 
                    DeffinitionToCommit=ProtNameTempHolder; //TopHitTerm[n];
                    DeffinitionToCommit = DeffinitionToCommit.replaceAll("\t", " ");
                    DeffinitionToCommit = DeffinitionToCommit.trim();

                    prep.setString(1,AccessionToCommit);
                    prep.setString(2,DeffinitionToCommit.trim());
                    prep.setString(3,DeffinitionAttributeFlag);
                    prep.addBatch();
                    
                    uniprot_parsed_writer.write(AccessionToCommit + "\t" + DeffinitionAttributeFlag + "\t" + DeffinitionToCommit + "\n");
                    
                    TaxonomyHolderforDB = NCBITaxNumericalValueClipped + "  " + TaxonomyTempHolder; //TaxInfo[n];
                    StringTokenizer st2a = new StringTokenizer(TaxonomyHolderforDB); 
                    if(st2a.hasMoreTokens())  {
                        TaxonomyToCommit  = st2a.nextToken();   	   
                        prep.setString(1,AccessionToCommit);
                        prep.setString(2,TaxonomyToCommit);
                        prep.setString(3,TaxonomyAttributeFlag);
                        prep.addBatch();
                        
                        uniprot_parsed_writer.write(AccessionToCommit + "\t" + TaxonomyAttributeFlag + "\t" + TaxonomyToCommit + "\n");
                        
                        taxonomy_data_file_writer.write(TaxonomyHolderforDB + "\n");
                        
                    }
                    
                    
                    goTermHolderforDB = GOValue; //goValueArray[n];
                    StringTokenizer st3 = new StringTokenizer(goTermHolderforDB); 
                    if(st3.hasMoreTokens()) {
                        while (st3.hasMoreTokens()) {
                            goTermForSplit = st3.nextToken();  
                            SplitArray1= goTermForSplit.split(BarDelimit);
                            goTermToCommit = SplitArray1[0]+":"+SplitArray1[1];
                            goTermToCommit = goTermToCommit.substring(0, goTermToCommit.length() - 1);
                            goTermToCommit = goTermToCommit.trim();

                            prep.setString(1,AccessionToCommit);
                            prep.setString(2,goTermToCommit);
                            prep.setString(3,goAttributeFlag );
                            prep.addBatch();
                            
                            uniprot_parsed_writer.write(AccessionToCommit + "\t" + goAttributeFlag + "\t" + goTermToCommit + "\n");
                            
                        }
                    }
                    
                    keggTermHolderforDB   = KeggValue; //KEGGValueArray[n]; 
                    StringTokenizer st4 = new StringTokenizer(keggTermHolderforDB); 
                    if(st4.hasMoreTokens()) {
                        while (st4.hasMoreTokens())  {
                            keggToCommit  = st4.nextToken();
                            keggToCommit = keggToCommit.trim();
                            prep.setString(1,AccessionToCommit);
                            prep.setString(2,keggToCommit);
                            prep.setString(3,KEGGAttributeFlag );
                            prep.addBatch();
                            
                            uniprot_parsed_writer.write(AccessionToCommit + "\t" + KEGGAttributeFlag + "\t" + keggToCommit + "\n");
                        }
                    }
                    
                    eggNOGHolderforDB = EggNogValue; //eggNOGValueArray[n];
                    StringTokenizer st5 = new StringTokenizer(eggNOGHolderforDB);
                    if(st5.hasMoreTokens())	{		
                        while (st5.hasMoreTokens()) {
                            eggNOGToCommit  = st5.nextToken();   
                            eggNOGToCommit = eggNOGToCommit.substring(0, eggNOGToCommit.length() - 1);	   
                            eggNOGToCommit = eggNOGToCommit.trim();
                            prep.setString(1,AccessionToCommit);
                            prep.setString(2,eggNOGToCommit);
                            prep.setString(3,eggNOGAttributeFLAG );
                            prep.addBatch();
                        }
                    }
                    
                    prep.executeBatch();
                
                
                    //-----------------------------------
                    // end of database writing section.
                    //-----------------------------------
                    
                    // Init tmp values for next entry capture.

                    SentFLAG=0;
                    SeqeunceValueForPrint="";
                    ProtNameTempHolder = "";
                    GeneNameTempHolder = "";
                    DETokenHolder= "";
                    RefSeqTempHolder = "";
                    GeneIdTempHolder = "";
                    GeneNameTokenHolder="";
                    TaxonomyTempHolder="";
                    TaxTempTokenHolder="";
                    GOTempTokenHolder = "";
                    eggNOGTempTokenHolder = "";
                    KEGGTempTokenHolder= "";
                    GOvalueTempTokenHolder = "";
                    KeyWorkTempTokenHolder = "";
                    UniprotDbaseTokenHolder="";
                    NCBITaxNumericalValue ="";
                    NCBITaxNumericalValueClipped ="";
                    RefSeqValue = "";
                    IDValue= "";
                    GoTokenValue = "";
                    EggNogValue = "";
                    KeggValue = "";
                    GOValue = "";
                    EMBLValue = "";
                    
                }
                // end of individual record processing.
                
                /*
                  else if (1==SentFLAG) {
                  SeqForBuild=TokenCheck;
                  if(st2.hasMoreTokens()) {
                  while (st2.hasMoreTokens()) {
                  TempSequneceHodler=st2.nextToken();
                  SeqForBuild=SeqForBuild +TempSequneceHodler;
                  }
                  SeqeunceValueForPrint = SeqeunceValueForPrint +SeqForBuild;
                  SeqForBuild="";
                  }
                  }
                */
                
            } // end of scanner.hasNextLine()
            
            // Done parsing EMBL file
            
            
            
            /*
            Writer output2 = null;
            File fileouter2 = new File("Taxonomyvalue.pre");
            output2=new BufferedWriter(new FileWriter(fileouter2, true));
            for (int p=0; p<PostArrayCounter; p++) { 
                String tempholder2 = TaxInfo[p];
                output2.write(tempholder2+System.getProperty( "line.separator" ));
            } 
            output2.close();
            */
    
            /*	Writer output9 = null;
                File fileouter9 = new File("Sequnece.pre");
                output9=new BufferedWriter(new FileWriter(fileouter9, true));
                for (int p=0; p<PostArrayCounter; p++)
                { 
                String tempholder9 = SequenceValueArray[p];
                output9.write(tempholder9+System.getProperty( "line.separator" ));
                } 
                output9.close();
            */
            
         
            
            conn.setAutoCommit(true);
            conn.close();
        
            
            uniprot_parsed_writer.close();
            taxonomy_data_file_writer.close();
            
        }
        catch (Exception e){//Catch exception if any
            System.err.println("Error: " + e.getMessage());
            System.exit(1);
        }
    } // end of main
} // end of class










